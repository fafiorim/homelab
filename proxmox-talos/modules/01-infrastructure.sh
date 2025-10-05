#!/bin/bash

# =============================================================================
# Module: Infrastructure (Proxmox VMs + Talos Kubernetes)
# =============================================================================
# This module handles:
# - Proxmox VM creation with qemu-agent support
# - Talos configuration generation with network patches  
# - Kubernetes cluster bootstrapping and verification
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Module configuration
MODULE_NAME="Infrastructure"
MODULE_VERSION="1.0.0"
REQUIRED_TOOLS=("curl" "jq" "talosctl" "kubectl")

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../cluster.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Configuration file $CONFIG_FILE not found${NC}"
    exit 1
fi

source "$CONFIG_FILE"

# VM Configuration
CONTROL_PLANE_VM_ID=400
WORKER_VM_IDS=(411 412)
VM_MEMORY=4096
VM_CORES=2
VM_DISK_SIZE=32

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_header() {
    echo -e "${BLUE}${BOLD}🏗️  Module: $MODULE_NAME v$MODULE_VERSION${NC}"
    echo ""
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool '$tool' not found"
            exit 1
        fi
    done
    
    # Check Proxmox API connectivity
    if ! curl -k -s -f -H "Authorization: PVEAPIToken=$proxmox_api_token_id=$proxmox_api_token_secret" \
        "$proxmox_api_url/nodes" > /dev/null; then
        log_error "Cannot connect to Proxmox API at $proxmox_api_url"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

cleanup_existing_vms() {
    log_info "Cleaning up existing VMs..."
    
    local all_vm_ids=($CONTROL_PLANE_VM_ID "${WORKER_VM_IDS[@]}")
    local vms_found=false
    
    for vm_id in "${all_vm_ids[@]}"; do
        log_info "Checking VM $vm_id..."
        
        # Check if VM exists
        local vm_info=$(curl -k -s -H "Authorization: PVEAPIToken=$proxmox_api_token_id=$proxmox_api_token_secret" \
            "$proxmox_api_url/nodes/$proxmox_node/qemu/$vm_id" 2>/dev/null)
        
        if echo "$vm_info" | jq -e '.data' > /dev/null 2>&1; then
            vms_found=true
            local vm_name=$(echo "$vm_info" | jq -r '.data.name // "unknown"' 2>/dev/null || echo "unknown")
            local vm_status=$(echo "$vm_info" | jq -r '.data.status // "unknown"' 2>/dev/null || echo "unknown")
            
            log_warning "Found existing VM $vm_id ($vm_name) with status: $vm_status"
            
            # Force stop VM first
            log_info "Force stopping VM $vm_id..."
            curl -k -s -X POST \
                -H "Authorization: PVEAPIToken=$proxmox_api_token_id=$proxmox_api_token_secret" \
                "$proxmox_api_url/nodes/$proxmox_node/qemu/$vm_id/status/stop" > /dev/null 2>&1
            
            # Wait a bit
            sleep 5
            
            # Force delete VM with destroy flag
            log_info "Force deleting VM $vm_id..."
            local delete_result=$(curl -k -s -X DELETE \
                -H "Authorization: PVEAPIToken=$proxmox_api_token_id=$proxmox_api_token_secret" \
                "$proxmox_api_url/nodes/$proxmox_node/qemu/$vm_id?destroy-unreferenced-disks=1&purge=1" 2>/dev/null)
            
            if echo "$delete_result" | jq -e '.data' > /dev/null 2>&1; then
                log_success "VM $vm_id deleted successfully"
            else
                # Try one more time with skiplock
                log_warning "Retrying VM $vm_id deletion with skiplock..."
                curl -k -s -X DELETE \
                    -H "Authorization: PVEAPIToken=$proxmox_api_token_id=$proxmox_api_token_secret" \
                    "$proxmox_api_url/nodes/$proxmox_node/qemu/$vm_id?destroy-unreferenced-disks=1&purge=1&skiplock=1" > /dev/null 2>&1
                log_success "VM $vm_id force deleted"
            fi
            
            sleep 3
        else
            log_info "VM $vm_id does not exist, skipping"
        fi
    done
    
    if [ "$vms_found" = false ]; then
        log_info "No existing VMs found to clean up"
    fi
    
    # Clean local files
    if [ -d "talos-configs" ] || [ -f "kubeconfig" ] || [ -f "talos-secrets.yaml" ]; then
        log_info "Cleaning up local configuration files..."
        rm -rf talos-configs kubeconfig talos-secrets.yaml
        log_success "Local files cleaned up"
    fi
    
    log_success "Cleanup completed"
}

create_vm() {
    local vm_id=$1
    local vm_name=$2
    local vm_ip=$3
    local vm_mac=$4
    
    log_info "Creating VM $vm_id ($vm_name) with IP $vm_ip"
    
    # Create VM configuration JSON
    local vm_config="{
        \"vmid\": $vm_id,
        \"name\": \"$vm_name\",
        \"cores\": $VM_CORES,
        \"sockets\": 1,
        \"memory\": $VM_MEMORY,
        \"boot\": \"order=ide2;scsi0\",
        \"scsihw\": \"virtio-scsi-pci\",
        \"agent\": 1,
        \"ostype\": \"l26\",
        \"cpu\": \"host\",
        \"numa\": false,
        \"net0\": \"virtio,bridge=${network_bridge},firewall=0,macaddr=$vm_mac\",
        \"scsi0\": \"${storage_pool}:${VM_DISK_SIZE},format=raw\",
        \"ide2\": \"${iso_storage}:iso/${talos_iso},media=cdrom\"
    }"
    
    # Create the VM
    local create_response=$(curl -k -s -X POST \
        -H "Authorization: PVEAPIToken=$proxmox_api_token_id=$proxmox_api_token_secret" \
        -H "Content-Type: application/json" \
        -d "$vm_config" \
        "$proxmox_api_url/nodes/$proxmox_node/qemu")
    
    if echo "$create_response" | jq -e '.data' > /dev/null; then
        log_success "VM $vm_id created successfully"
    else
        log_error "Failed to create VM $vm_id: $create_response"
        return 1
    fi
    
    # Start VM
    curl -k -s -X POST \
        -H "Authorization: PVEAPIToken=$proxmox_api_token_id=$proxmox_api_token_secret" \
        "$proxmox_api_url/nodes/$proxmox_node/qemu/$vm_id/status/start" > /dev/null
    
    log_success "VM $vm_id started with Talos ISO"
}

deploy_vms() {
    log_info "Deploying Proxmox VMs..."
    
    # Create control plane VM
    create_vm $CONTROL_PLANE_VM_ID "talos-cp-01" "$control_plane_ip" "$control_plane_mac"
    
    # Create worker VMs
    create_vm ${WORKER_VM_IDS[0]} "talos-worker-01" "$worker_node_01_ip" "$worker_01_mac"
    create_vm ${WORKER_VM_IDS[1]} "talos-worker-02" "$worker_node_02_ip" "$worker_02_mac"
    
    log_info "Waiting for VMs to fully boot with Talos ISO..."
    log_info "This may take 2-3 minutes for Talos to initialize and start API..."
    
    # Wait for VMs to show as running in Proxmox
    log_info "Checking VM status in Proxmox..."
    local all_running=false
    local check_count=0
    local max_checks=20
    
    while [ $check_count -lt $max_checks ] && [ "$all_running" = false ]; do
        local running_count=0
        local all_vm_ids=($CONTROL_PLANE_VM_ID "${WORKER_VM_IDS[@]}")
        
        for vm_id in "${all_vm_ids[@]}"; do
            local vm_status=$(curl -k -s -H "Authorization: PVEAPIToken=$proxmox_api_token_id=$proxmox_api_token_secret" \
                "$proxmox_api_url/nodes/$proxmox_node/qemu/$vm_id/status/current" | jq -r '.data.status // "unknown"' 2>/dev/null)
            
            if [ "$vm_status" = "running" ]; then
                ((running_count++))
            fi
        done
        
        if [ $running_count -eq ${#all_vm_ids[@]} ]; then
            all_running=true
            log_success "All VMs are running in Proxmox"
        else
            log_info "VMs starting... ($running_count/${#all_vm_ids[@]} running)"
            sleep 10
            ((check_count++))
        fi
    done
    
    if [ "$all_running" = false ]; then
        log_error "Not all VMs started properly"
        return 1
    fi
    
    # Additional wait for Talos to boot
    log_info "Waiting additional time for Talos OS to boot..."
    sleep 60
    
    log_success "All VMs deployed and running"
}

generate_talos_config() {
    log_info "Generating Talos configuration..."
    
    # Create talos-configs directory
    mkdir -p talos-configs
    
    # Generate base configuration
    talosctl gen config "$cluster_name" "https://$control_plane_ip:6443" \
        --output-dir talos-configs/
    
    # Create network patches for each node
    cat > talos-configs/control-plane-patch.yaml << EOF
machine:
  network:
    interfaces:
      - interface: eth0
        dhcp: false
        addresses:
          - $control_plane_ip/24
        routes:
          - network: 0.0.0.0/0
            gateway: 10.10.21.1
        mtu: 1500
    nameservers:
      - 8.8.8.8
      - 1.1.1.1
EOF

    cat > talos-configs/worker-01-patch.yaml << EOF
machine:
  network:
    interfaces:
      - interface: eth0
        dhcp: false
        addresses:
          - $worker_node_01_ip/24
        routes:
          - network: 0.0.0.0/0
            gateway: 10.10.21.1
        mtu: 1500
    nameservers:
      - 8.8.8.8
      - 1.1.1.1
EOF

    cat > talos-configs/worker-02-patch.yaml << EOF
machine:
  network:
    interfaces:
      - interface: eth0
        dhcp: false
        addresses:
          - $worker_node_02_ip/24
        routes:
          - network: 0.0.0.0/0
            gateway: 10.10.21.1
        mtu: 1500
    nameservers:
      - 8.8.8.8
      - 1.1.1.1
EOF
    
    log_success "Talos configuration generated"
}

discover_talos_nodes() {
    log_info "Discovering Talos nodes in maintenance mode..."
    
    # Talos nodes boot with DHCP first, then we apply static config
    # We need to find them on the network first
    local network_range="10.10.21"
    local discovered_nodes=()
    
    log_info "Scanning network for Talos nodes..."
    
    # Scan a reasonable range for DHCP-assigned IPs
    for i in {100..120}; do
        local test_ip="$network_range.$i"
        if talosctl --nodes "$test_ip" version --insecure --timeout 2s > /dev/null 2>&1; then
            log_success "Found Talos node at $test_ip"
            discovered_nodes+=("$test_ip")
        fi
    done
    
    if [ ${#discovered_nodes[@]} -lt 3 ]; then
        log_error "Could not discover all Talos nodes. Found: ${#discovered_nodes[@]}/3"
        log_info "Trying alternative discovery method..."
        
        # Alternative: check VM console IPs via Proxmox agent
        local all_vm_ids=($CONTROL_PLANE_VM_ID "${WORKER_VM_IDS[@]}")
        discovered_nodes=()
        
        for vm_id in "${all_vm_ids[@]}"; do
            log_info "Getting IP for VM $vm_id..."
            local vm_ip=$(curl -k -s -H "Authorization: PVEAPIToken=$proxmox_api_token_id=$proxmox_api_token_secret" \
                "$proxmox_api_url/nodes/$proxmox_node/qemu/$vm_id/agent/network-get-interfaces" 2>/dev/null | \
                jq -r '.data[] | select(.name=="eth0") | .["ip-addresses"][]? | select(.["ip-address-type"]=="ipv4") | .["ip-address"]' 2>/dev/null || echo "")
            
            if [ -n "$vm_ip" ] && [ "$vm_ip" != "127.0.0.1" ]; then
                log_success "VM $vm_id has IP: $vm_ip"
                discovered_nodes+=("$vm_ip")
            fi
        done
    fi
    
    if [ ${#discovered_nodes[@]} -lt 3 ]; then
        log_error "Could not discover sufficient Talos nodes"
        return 1
    fi
    
    # Store discovered IPs for configuration
    DISCOVERED_CONTROL_PLANE="${discovered_nodes[0]}"
    DISCOVERED_WORKER_01="${discovered_nodes[1]}"
    DISCOVERED_WORKER_02="${discovered_nodes[2]}"
    
    log_success "Discovered nodes: ${discovered_nodes[*]}"
}

apply_talos_config() {
    log_info "Applying Talos configuration to nodes..."
    
    # Use static IPs from DHCP reservations (MAC addresses are correctly configured)
    log_info "Using DHCP reservation IPs - Control Plane: $control_plane_ip, Workers: $worker_node_01_ip, $worker_node_02_ip"
    
    # Apply configuration to control plane
    log_info "Applying configuration to control plane at $control_plane_ip..."
    if ! talosctl apply-config --insecure \
        --nodes "$control_plane_ip" \
        --file talos-configs/controlplane.yaml; then
        log_error "Failed to apply configuration to control plane"
        return 1
    fi
    
    # Apply configuration to workers
    log_info "Applying configuration to worker-01 at $worker_node_01_ip..."
    if ! talosctl apply-config --insecure \
        --nodes "$worker_node_01_ip" \
        --file talos-configs/worker.yaml; then
        log_error "Failed to apply configuration to worker-01"
        return 1
    fi
        
    log_info "Applying configuration to worker-02 at $worker_node_02_ip..."
    if ! talosctl apply-config --insecure \
        --nodes "$worker_node_02_ip" \
        --file talos-configs/worker.yaml; then
        log_error "Failed to apply configuration to worker-02"
        return 1
    fi
    
    log_info "Waiting for nodes to configure and restart..."
    sleep 60
    
    log_success "Talos configuration applied to all nodes"
}

bootstrap_cluster() {
    log_info "Bootstrapping Kubernetes cluster..."
    
    # Set talosctl config to use the generated config
    export TALOSCONFIG=talos-configs/talosconfig
    talosctl config endpoint $control_plane_ip
    talosctl config node $control_plane_ip
    
    # Wait for nodes to be ready for bootstrap
    log_info "Waiting for control plane to be ready for bootstrap..."
    local max_wait=120
    local waited=0
    
    while [ $waited -lt $max_wait ]; do
        if talosctl version --nodes $control_plane_ip &> /dev/null; then
            log_success "Control plane is ready for bootstrap"
            break
        fi
        log_info "Waiting for control plane... ($waited/${max_wait}s)"
        sleep 10
        waited=$((waited + 10))
    done
    
    if [ $waited -ge $max_wait ]; then
        log_error "Timeout waiting for control plane to be ready"
        return 1
    fi
    
    # Bootstrap the cluster
    log_info "Bootstrapping cluster..."
    talosctl bootstrap --nodes $control_plane_ip
    
    log_info "Waiting for cluster to initialize..."
    sleep 30
    
    # Get kubeconfig
    talosctl kubeconfig .
    
    # Wait for all nodes to be ready
    log_info "Waiting for all nodes to be ready..."
    export KUBECONFIG=./kubeconfig
    
    local max_attempts=20
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
        if [ "$ready_nodes" = "3" ]; then
            log_success "All 3 nodes are ready!"
            break
        fi
        
        log_info "Attempt $attempt/$max_attempts: $ready_nodes/3 nodes ready"
        sleep 15
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "Timeout waiting for nodes to become ready"
        return 1
    fi
    
    log_success "Kubernetes cluster bootstrapped successfully"
}

verify_cluster() {
    log_info "Verifying cluster health..."
    
    export KUBECONFIG=./kubeconfig
    
    # Check nodes
    log_info "Cluster nodes:"
    kubectl get nodes -o wide
    
    # Check system pods
    log_info "System pods status:"
    kubectl get pods -n kube-system
    
    log_success "Cluster verification completed"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    show_header
    
    check_prerequisites
    cleanup_existing_vms
    deploy_vms
    generate_talos_config
    apply_talos_config
    bootstrap_cluster
    verify_cluster
    
    log_success "Infrastructure module completed successfully!"
    echo ""
    echo -e "${GREEN}✅ Talos Kubernetes cluster is ready${NC}"
    echo -e "${BLUE}📄 kubeconfig saved to: ./kubeconfig${NC}"
    echo -e "${BLUE}🔧 Talos config saved to: talos-configs/${NC}"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi