#!/bin/bash

# Master deployment script for Talos Kubernetes cluster
# This script checks for existing VMs, creates them if needed, and configures the cluster

# Load configuration from cluster.conf
if [ ! -f "cluster.conf" ]; then
    echo "Error: cluster.conf file not found!"
    echo "Please copy cluster.conf.example to cluster.conf and configure it."
    exit 1
fi

# Parse cluster.conf file and export variables
while IFS='=' read -r key value; do
    # Skip comments and empty lines
    if [[ $key =~ ^[[:space:]]*# ]] || [[ -z "${key// }" ]]; then
        continue
    fi
    
    # Remove leading/trailing whitespace and quotes
    key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')
    
    # Export the variable
    export "$key"="$value"
done < cluster.conf

# Cluster Configuration
CLUSTER_ENDPOINT="https://${control_plane_ip}:6443"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to make API calls
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    if [ -n "$data" ]; then
        curl -k -X "$method" \
            -H "Authorization: PVEAPIToken=${proxmox_api_token_id}=${proxmox_api_token_secret}" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "${proxmox_api_url}${endpoint}"
    else
        curl -k -X "$method" \
            -H "Authorization: PVEAPIToken=${proxmox_api_token_id}=${proxmox_api_token_secret}" \
            "${proxmox_api_url}${endpoint}"
    fi
}

# Function to check if VM exists
check_vm_exists() {
    local vmid=$1
    local name=$2
    
    echo -e "${YELLOW}Checking if VM $name (ID: $vmid) exists...${NC}"
    
    local result=$(api_call "GET" "/cluster/resources?type=vm" 2>/dev/null)
    
    if echo "$result" | grep -q "\"vmid\":$vmid"; then
        echo -e "${RED}✗ VM $name (ID: $vmid) already exists!${NC}"
        return 0
    else
        echo -e "${GREEN}✓ VM $name (ID: $vmid) does not exist${NC}"
        return 1
    fi
}

# Function to check if any VMs exist
check_existing_vms() {
    echo -e "${YELLOW}Checking for existing VMs...${NC}"
    
    local control_exists=false
    local worker1_exists=false
    local worker2_exists=false
    
    if check_vm_exists 400 "talos-control-plane"; then
        control_exists=true
    fi
    
    if check_vm_exists 411 "talos-worker-01"; then
        worker1_exists=true
    fi
    
    if check_vm_exists 412 "talos-worker-02"; then
        worker2_exists=true
    fi
    
    if [ "$control_exists" = true ] || [ "$worker1_exists" = true ] || [ "$worker2_exists" = true ]; then
        echo ""
        echo -e "${RED}❌ ERROR: One or more VMs already exist!${NC}"
        echo -e "${YELLOW}Existing VMs:${NC}"
        [ "$control_exists" = true ] && echo -e "  - talos-control-plane (ID: 400)"
        [ "$worker1_exists" = true ] && echo -e "  - talos-worker-01 (ID: 411)"
        [ "$worker2_exists" = true ] && echo -e "  - talos-worker-02 (ID: 412)"
        echo ""
        echo -e "${YELLOW}Please delete existing VMs first or use different VM IDs.${NC}"
        echo -e "${BLUE}To delete VMs via Proxmox web interface:${NC}"
        echo -e "  1. Go to each VM → More → Destroy"
        echo -e "  2. Or use the cleanup script: ./cleanup_vms.sh"
        exit 1
    fi
    
    echo -e "${GREEN}✓ No conflicting VMs found. Safe to proceed.${NC}"
}

# Function to create VM
create_vm() {
    local vmid=$1
    local name=$2
    local macaddr=$3
    local ip_comment=$4
    
    echo -e "${YELLOW}Creating VM: $name (ID: $vmid)${NC}"
    
    # Create VM configuration
    local vm_config="{
        \"vmid\": $vmid,
        \"name\": \"$name\",
        \"cores\": 4,
        \"sockets\": 1,
        \"memory\": 6144,
        \"boot\": \"order=ide2;scsi0\",
        \"scsihw\": \"virtio-scsi-pci\",
        \"agent\": 0,
        \"ostype\": \"l26\",
        \"cpu\": \"host\",
        \"numa\": false,
        \"hotplug\": \"network,disk,usb\",
        \"net0\": \"virtio,bridge=${network_bridge},macaddr=$macaddr,firewall=0\",
        \"scsi0\": \"${storage_pool}:50,format=raw\",
        \"ide2\": \"${iso_storage}:iso/${talos_iso},media=cdrom\",
        \"tags\": \"talos,$(if [[ $name == *control* ]]; then echo 'control-plane'; else echo 'worker'; fi)\"
    }"
    
    # Create the VM
    local result=$(api_call "POST" "/nodes/${proxmox_node}/qemu" "$vm_config")
    
    if echo "$result" | grep -q '"data":'; then
        echo -e "${GREEN}✓ VM $name created successfully${NC}"
        echo -e "  - VM ID: $vmid"
        echo -e "  - IP: $ip_comment"
        echo -e "  - MAC: $macaddr"
        echo -e "  - Specs: 4 cores, 1 socket, 6GB RAM, 50GB disk"
        return 0
    else
        echo -e "${RED}✗ Failed to create VM $name${NC}"
        echo "Error: $result"
        return 1
    fi
}

# Function to start VM
start_vm() {
    local vmid=$1
    local name=$2
    
    echo -e "${YELLOW}Starting VM: $name (ID: $vmid)${NC}"
    
    local result=$(api_call "POST" "/nodes/${proxmox_node}/qemu/$vmid/status/start")
    
    if echo "$result" | grep -q '"data":'; then
        echo -e "${GREEN}✓ VM $name started successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to start VM $name${NC}"
        echo "Error: $result"
        return 1
    fi
}

# Function to check if talosctl is installed
check_talosctl() {
    if ! command -v talosctl >/dev/null 2>&1; then
        echo -e "${RED}✗ talosctl is not installed${NC}"
        echo -e "${YELLOW}Please install talosctl first:${NC}"
        echo ""
        echo "On macOS:"
        echo "  brew install talosctl"
        echo ""
        echo "On Linux:"
        echo "  curl -sL https://talos.dev/install | sh"
        echo ""
        echo "On Windows:"
        echo "  choco install talosctl"
        echo ""
        exit 1
    fi
    echo -e "${GREEN}✓ talosctl is installed${NC}"
}

# Function to generate Talos machine configs
generate_configs() {
    echo -e "${YELLOW}Generating Talos machine configurations...${NC}"
    
    # Generate cluster configuration
    talosctl gen config "${cluster_name}" "$CLUSTER_ENDPOINT" \
        --output-dir ./talos-configs \
        --with-docs=false \
        --with-examples=false
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Talos machine configs generated successfully${NC}"
        echo -e "  - Control plane config: ./talos-configs/controlplane.yaml"
        echo -e "  - Worker config: ./talos-configs/worker.yaml"
        echo -e "  - Talos config: ./talos-configs/talosconfig"
        echo -e "  - Secrets: ./talos-secrets.yaml"
    else
        echo -e "${RED}✗ Failed to generate Talos machine configs${NC}"
        exit 1
    fi
}

# Function to apply machine configurations
apply_configs() {
    echo -e "${YELLOW}Applying machine configurations...${NC}"
    
    # Apply control plane config
    echo -e "${BLUE}Applying control plane configuration (VM 400)...${NC}"
    talosctl apply-config --insecure --nodes "${control_plane_ip}" --file ./talos-configs/controlplane.yaml
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Control plane configuration applied${NC}"
    else
        echo -e "${RED}✗ Failed to apply control plane configuration${NC}"
        exit 1
    fi
    
    # Apply worker configs
    echo -e "${BLUE}Applying worker configuration (VM 411)...${NC}"
    talosctl apply-config --insecure --nodes "${worker_node_01_ip}" --file ./talos-configs/worker.yaml
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Worker 01 configuration applied${NC}"
    else
        echo -e "${RED}✗ Failed to apply worker 01 configuration${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Applying worker configuration (VM 412)...${NC}"
    talosctl apply-config --insecure --nodes "${worker_node_02_ip}" --file ./talos-configs/worker.yaml
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Worker 02 configuration applied${NC}"
    else
        echo -e "${RED}✗ Failed to apply worker 02 configuration${NC}"
        exit 1
    fi
}

# Function to bootstrap the cluster
bootstrap_cluster() {
    echo -e "${YELLOW}Bootstrapping Talos cluster...${NC}"
    
    # Set talosconfig
    export TALOSCONFIG="./talos-configs/talosconfig"
    
    # Set endpoint
    talosctl --talosconfig="$TALOSCONFIG" config endpoint "${control_plane_ip}"
    
    # Bootstrap the cluster
    talosctl --talosconfig="$TALOSCONFIG" bootstrap --nodes "${control_plane_ip}"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Cluster bootstrapped successfully${NC}"
    else
        echo -e "${RED}✗ Failed to bootstrap cluster${NC}"
        exit 1
    fi
}

# Function to retrieve kubeconfig
get_kubeconfig() {
    echo -e "${YELLOW}Retrieving kubeconfig...${NC}"
    
    export TALOSCONFIG="./talos-configs/talosconfig"
    
    # Get kubeconfig with proper node specification
    talosctl --talosconfig="$TALOSCONFIG" kubeconfig . --nodes "${control_plane_ip}"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Kubeconfig retrieved successfully${NC}"
        echo -e "  - Kubeconfig file: ./kubeconfig"
    else
        echo -e "${RED}✗ Failed to retrieve kubeconfig${NC}"
        exit 1
    fi
}

# Function to verify cluster status
verify_cluster() {
    echo -e "${YELLOW}Verifying cluster status...${NC}"
    
    export TALOSCONFIG="./talos-configs/talosconfig"
    export KUBECONFIG="./kubeconfig"
    
    # Wait a moment for nodes to be ready
    echo -e "${BLUE}Waiting for nodes to be ready...${NC}"
    sleep 30
    
    # Check nodes with retry logic
    echo -e "${BLUE}Checking cluster nodes:${NC}"
    local retry_count=0
    local max_retries=5
    
    while [ $retry_count -lt $max_retries ]; do
        if kubectl get nodes -o wide 2>/dev/null; then
            echo -e "${GREEN}✓ All nodes are accessible${NC}"
            break
        else
            retry_count=$((retry_count + 1))
            echo -e "${YELLOW}⚠️  Nodes not ready yet (attempt $retry_count/$max_retries), waiting 15s...${NC}"
            sleep 15
        fi
    done
    
    if [ $retry_count -eq $max_retries ]; then
        echo -e "${YELLOW}⚠️  Nodes may still be initializing. Cluster info will be displayed anyway.${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Checking cluster info:${NC}"
    kubectl cluster-info 2>/dev/null || echo -e "${YELLOW}⚠️  Cluster info not available yet${NC}"
}

# Function to display cluster information and status
display_info() {
    echo ""
    echo -e "${GREEN}=== Talos Cluster Setup Complete ===${NC}"
    echo ""
    echo -e "${BLUE}Cluster Information:${NC}"
    echo -e "  - Cluster Name: ${cluster_name}"
    echo -e "  - Control Plane: ${control_plane_ip} (VM 400)"
    echo -e "  - Worker 01: ${worker_node_01_ip} (VM 411)"
    echo -e "  - Worker 02: ${worker_node_02_ip} (VM 412)"
    echo -e "  - API Endpoint: $CLUSTER_ENDPOINT"
    echo ""
    
    # Automatically set environment variables for this session
    export KUBECONFIG="./kubeconfig"
    export TALOSCONFIG="./talos-configs/talosconfig"
    
    echo -e "${BLUE}Current Cluster Status:${NC}"
    echo -e "${YELLOW}Checking nodes...${NC}"
    if kubectl get nodes -o wide 2>/dev/null; then
        echo ""
        echo -e "${YELLOW}Checking system pods...${NC}"
        kubectl get pods -A --field-selector=status.phase=Running 2>/dev/null | head -10
        if [ $(kubectl get pods -A --field-selector=status.phase=Running 2>/dev/null | wc -l) -gt 10 ]; then
            echo -e "${BLUE}... and more system pods running${NC}"
        fi
        echo ""
        echo -e "${GREEN}✅ Your Talos Kubernetes cluster is ready!${NC}"
    else
        echo -e "${YELLOW}⚠️  Cluster might still be initializing. Wait a moment and try: kubectl get nodes${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Configuration Files:${NC}"
    echo -e "  - Talos Config: ./talos-configs/talosconfig"
    echo -e "  - Kubeconfig: ./kubeconfig"
    echo ""
    echo -e "${BLUE}To use kubectl, first set up your environment:${NC}"
    echo -e "${YELLOW}# Run this command to set up your environment:${NC}"
    echo -e "${GREEN}source ./setup-env.sh${NC}"
    echo ""
    echo -e "${YELLOW}# Or manually export:${NC}"
    echo -e "export KUBECONFIG=./kubeconfig"  
    echo -e "export TALOSCONFIG=./talos-configs/talosconfig"
    echo ""
    echo -e "${BLUE}Then you can use:${NC}"
    echo -e "  kubectl get nodes"
    echo -e "  kubectl get pods -A"
    echo -e "  kubectl cluster-info"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "  ./talos-cluster.sh argocd    # Install ArgoCD for GitOps"
    echo -e "  ./talos-cluster.sh apps      # Deploy applications"
    echo ""
    echo -e "${YELLOW}Note: Keep the configuration files secure!${NC}"
}

# Main execution
echo -e "${GREEN}=== Talos Kubernetes Cluster Deployment ===${NC}"
echo -e "Cluster Name: ${cluster_name}"
echo -e "Control Plane: ${control_plane_ip} (VM 400)"
echo -e "Workers: ${worker_node_01_ip} (VM 411), ${worker_node_02_ip} (VM 412)"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
check_talosctl

# Check for existing VMs
check_existing_vms

# Check if Talos ISO exists
echo -e "${YELLOW}Checking if Talos ISO exists...${NC}"
iso_check=$(api_call "GET" "/nodes/${proxmox_node}/storage/${iso_storage}/content")
if echo "$iso_check" | grep -q "${talos_iso}"; then
    echo -e "${GREEN}✓ Talos ISO found${NC}"
else
    echo -e "${RED}✗ Talos ISO not found. Please upload ${talos_iso} to ${iso_storage} storage${NC}"
    exit 1
fi

echo ""

# Create VMs
echo -e "${YELLOW}Creating VMs...${NC}"
create_vm 400 "talos-control-plane" "${control_plane_mac}" "${control_plane_ip}"
create_vm 411 "talos-worker-01" "${worker_01_mac}" "${worker_node_01_ip}"
create_vm 412 "talos-worker-02" "${worker_02_mac}" "${worker_node_02_ip}"

echo ""

# Start VMs
echo -e "${YELLOW}Starting VMs...${NC}"
start_vm 400 "talos-control-plane"
start_vm 411 "talos-worker-01"
start_vm 412 "talos-worker-02"

echo ""

# Wait for VMs to be ready
echo -e "${YELLOW}Waiting for VMs to be ready...${NC}"
sleep 80

# Create config directory
mkdir -p ./talos-configs

# Generate Talos configurations
generate_configs

echo ""

# Apply configurations
apply_configs

echo ""

# Wait for nodes to initialize
echo -e "${YELLOW}Waiting for nodes to initialize...${NC}"
sleep 90

# Bootstrap cluster
bootstrap_cluster

# Get kubeconfig
get_kubeconfig

# Verify cluster
verify_cluster

# Display final information
display_info

echo ""
echo -e "${GREEN}🎉 Talos cluster '${cluster_name}' is ready!${NC}"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: To use kubectl, run this command first:${NC}"
echo -e "${GREEN}source ./setup-env.sh${NC}"
echo ""
