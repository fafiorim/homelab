#!/bin/bash

# Proxmox Talos Kubernetes Cluster - Main Management Script
# This is the single entry point for all cluster operations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
FORCE_DELETE_EXISTING_VMS=false
VM_IDS=(400 411 412)
VM_NAMES=("talos-control-plane" "talos-worker-01" "talos-worker-02")

# Function to display banner
show_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    Proxmox Talos Kubernetes Cluster Manager                 ║"
    echo "║                              Main Management Script                         ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Function to display usage
usage() {
    echo -e "${CYAN}Usage: $0 [COMMAND] [OPTIONS]${NC}"
    echo ""
    echo "Commands:"
    echo "  deploy          Deploy complete Talos Kubernetes cluster"
    echo "  cleanup         Remove all VMs and configurations"
    echo "  status          Show cluster and VM status"
    echo "  help            Show this help message"
    echo ""
    echo "Options:"
    echo "  --force         Force delete existing VMs with same IDs"
    echo "  --verbose       Enable verbose output"
    echo "  --dry-run       Show what would be done without executing"
    echo ""
    echo "Examples:"
    echo "  $0 deploy                    # Deploy cluster (will error if VMs exist)"
    echo "  $0 deploy --force           # Deploy cluster, delete existing VMs first"
    echo "  $0 cleanup                  # Remove all VMs and configurations"
    echo "  $0 status                   # Show current status"
    echo ""
    echo "Configuration:"
    echo "  Edit cluster.conf to configure Proxmox and cluster settings"
    echo "  VM IDs: ${VM_IDS[*]}"
    echo "  VM Names: ${VM_NAMES[*]}"
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"
    
    local missing=()
    
    # Check required commands
    command -v talosctl >/dev/null 2>&1 || missing+=("talosctl")
    command -v kubectl >/dev/null 2>&1 || missing+=("kubectl")
    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    
    # Check configuration file
    if [ ! -f "cluster.conf" ]; then
        echo -e "${RED}✗ cluster.conf not found${NC}"
        echo -e "${YELLOW}Please copy cluster.conf.example to cluster.conf and configure it.${NC}"
        exit 1
    fi
    
    # Check if any missing
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}✗ Missing required commands: ${missing[*]}${NC}"
        echo -e "${YELLOW}Please install missing commands and try again.${NC}"
        echo ""
        echo "Installation commands:"
        echo "  macOS: brew install talosctl kubectl jq"
        echo "  Linux: curl -sL https://talos.dev/install | sh && apt-get install kubectl jq"
        exit 1
    fi
    
    echo -e "${GREEN}✓ All prerequisites met${NC}"
}

# Function to parse cluster.conf
parse_config() {
    echo -e "${YELLOW}📋 Loading configuration...${NC}"
    
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
    
    echo -e "${GREEN}✓ Configuration loaded${NC}"
}

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

# Function to check for existing VMs
check_existing_vms() {
    echo -e "${YELLOW}🔍 Checking for existing VMs...${NC}"
    
    local existing_vms=()
    local result=$(api_call "GET" "/cluster/resources?type=vm" 2>/dev/null)
    
    for i in "${!VM_IDS[@]}"; do
        local vmid="${VM_IDS[$i]}"
        local name="${VM_NAMES[$i]}"
        
        if echo "$result" | grep -q "\"vmid\":$vmid"; then
            existing_vms+=("$name (ID: $vmid)")
        fi
    done
    
    if [ ${#existing_vms[@]} -ne 0 ]; then
        echo -e "${RED}✗ Found existing VMs:${NC}"
        for vm in "${existing_vms[@]}"; do
            echo -e "  - $vm"
        done
        
        if [ "$FORCE_DELETE_EXISTING_VMS" = true ]; then
            echo -e "${YELLOW}Force mode enabled: Will delete existing VMs and continue.${NC}"
            return 0
        else
            echo ""
            echo -e "${YELLOW}Options:${NC}"
            echo -e "  1. Use --force to delete existing VMs and continue"
            echo -e "  2. Manually delete VMs via Proxmox web interface"
            echo -e "  3. Use different VM IDs in cluster.conf"
            echo ""
            echo -e "${BLUE}To force delete and continue: $0 deploy --force${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✓ No conflicting VMs found${NC}"
    fi
}

# Function to delete existing VMs
delete_existing_vms() {
    echo -e "${YELLOW}🗑️  Deleting existing VMs...${NC}"
    
    local result=$(api_call "GET" "/cluster/resources?type=vm" 2>/dev/null)
    
    for i in "${!VM_IDS[@]}"; do
        local vmid="${VM_IDS[$i]}"
        local name="${VM_NAMES[$i]}"
        
        if echo "$result" | grep -q "\"vmid\":$vmid"; then
            echo -e "${BLUE}  Deleting $name (ID: $vmid)...${NC}"
            
            # Stop VM first
            local stop_result=$(api_call "POST" "/nodes/${proxmox_node}/qemu/$vmid/status/shutdown")
            if echo "$stop_result" | grep -q '"data":'; then
                echo -e "${GREEN}    ✓ VM stopped${NC}"
            fi
            
            # Wait for shutdown
            sleep 5
            
            # Delete VM
            local delete_result=$(api_call "DELETE" "/nodes/${proxmox_node}/qemu/$vmid")
            if echo "$delete_result" | grep -q '"data":'; then
                echo -e "${GREEN}    ✓ VM deleted${NC}"
            else
                echo -e "${RED}    ✗ Failed to delete VM${NC}"
            fi
        fi
    done
    
    echo -e "${GREEN}✓ Existing VMs cleaned up${NC}"
}

# Function to deploy cluster
deploy_cluster() {
    echo -e "${GREEN}🚀 Starting cluster deployment...${NC}"
    
    check_prerequisites
    parse_config
    
    # Check for existing VMs
    check_existing_vms
    
    # Delete existing VMs if force mode is enabled
    if [ "$FORCE_DELETE_EXISTING_VMS" = true ]; then
        delete_existing_vms
        
        # Wait for VMs to be completely deleted
        echo -e "${YELLOW}⏳ Waiting for VMs to be completely deleted...${NC}"
        sleep 10
        
        # Verify VMs are actually deleted
        local result=$(api_call "GET" "/cluster/resources?type=vm" 2>/dev/null)
        local still_exist=false
        
        for i in "${!VM_IDS[@]}"; do
            local vmid="${VM_IDS[$i]}"
            if echo "$result" | grep -q "\"vmid\":$vmid"; then
                still_exist=true
                break
            fi
        done
        
        if [ "$still_exist" = true ]; then
            echo -e "${RED}✗ Some VMs still exist after deletion attempt${NC}"
            echo -e "${YELLOW}Please wait a moment and try again, or manually delete VMs via Proxmox${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}✓ All VMs successfully deleted${NC}"
        
        # Clean up configuration files
        echo -e "${YELLOW}🧹 Cleaning up configuration files...${NC}"
        local files_to_remove=(
            "./talos-configs"
            "./talos-secrets.yaml"
            "./kubeconfig"
        )
        
        for file in "${files_to_remove[@]}"; do
            if [ -e "$file" ]; then
                rm -rf "$file"
                echo -e "${GREEN}  ✓ Removed $file${NC}"
            fi
        done
        
        echo ""
    fi
    
    # Check if Talos ISO exists
    echo -e "${YELLOW}🔍 Checking Talos ISO...${NC}"
    local iso_check=$(api_call "GET" "/nodes/${proxmox_node}/storage/${iso_storage}/content")
    if echo "$iso_check" | grep -q "${talos_iso}"; then
        echo -e "${GREEN}✓ Talos ISO found${NC}"
    else
        echo -e "${RED}✗ Talos ISO not found: ${talos_iso}${NC}"
        echo -e "${YELLOW}Please upload the Talos ISO to ${iso_storage} storage${NC}"
        echo -e "${BLUE}Download from: https://github.com/siderolabs/talos/releases${NC}"
        exit 1
    fi
    
    echo ""
    
    # Deploy using the main deployment script
    echo -e "${YELLOW}📦 Deploying cluster...${NC}"
    ./deploy_talos_cluster.sh
    
    # Wait for cluster to be ready
    echo -e "${YELLOW}⏳ Waiting for cluster to be ready...${NC}"
    sleep 30
    
    # Verify cluster
    echo -e "${YELLOW}🔍 Verifying cluster...${NC}"
    export KUBECONFIG="./kubeconfig"
    
    # Wait for nodes to be ready
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if kubectl get nodes --no-headers 2>/dev/null | grep -q "Ready"; then
            break
        fi
        echo -e "${BLUE}  Waiting for nodes to be ready... (attempt $((attempt + 1))/$max_attempts)${NC}"
        sleep 10
        ((attempt++))
    done
    
    # Show final status
    echo ""
    echo -e "${GREEN}🎉 Cluster deployment complete!${NC}"
    echo ""
    echo -e "${BLUE}Cluster Status:${NC}"
    kubectl get nodes -o wide
    
    echo ""
    echo -e "${BLUE}System Pods:${NC}"
    kubectl get pods -A
    
    echo ""
    echo -e "${BLUE}Cluster Information:${NC}"
    echo -e "  - Cluster Name: ${cluster_name}"
    echo -e "  - Control Plane: ${control_plane_ip} (VM 400)"
    echo -e "  - Worker 01: ${worker_node_01_ip} (VM 411)"
    echo -e "  - Worker 02: ${worker_node_02_ip} (VM 412)"
    echo -e "  - API Endpoint: https://${control_plane_ip}:6443"
    echo ""
    echo -e "${BLUE}Usage:${NC}"
    echo -e "  export KUBECONFIG=./kubeconfig"
    echo -e "  kubectl get nodes"
    echo ""
    echo -e "${GREEN}✅ Your Talos Kubernetes cluster is ready!${NC}"
}

# Function to cleanup cluster
cleanup_cluster() {
    echo -e "${RED}🗑️  Starting cluster cleanup...${NC}"
    
    # Confirmation
    echo -e "${YELLOW}This will delete the following VMs and all configurations:${NC}"
    for i in "${!VM_IDS[@]}"; do
        echo -e "  - ${VM_NAMES[$i]} (ID: ${VM_IDS[$i]})"
    done
    echo ""
    
    read -p "Are you sure you want to proceed? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo -e "${YELLOW}Cleanup cancelled.${NC}"
        exit 0
    fi
    
    echo ""
    
    # Parse config for API calls
    parse_config
    
    # Delete VMs
    echo -e "${YELLOW}🗑️  Deleting VMs...${NC}"
    local result=$(api_call "GET" "/cluster/resources?type=vm" 2>/dev/null)
    
    for i in "${!VM_IDS[@]}"; do
        local vmid="${VM_IDS[$i]}"
        local name="${VM_NAMES[$i]}"
        
        if echo "$result" | grep -q "\"vmid\":$vmid"; then
            echo -e "${BLUE}  Deleting $name (ID: $vmid)...${NC}"
            
            # Stop VM first
            local stop_result=$(api_call "POST" "/nodes/${proxmox_node}/qemu/$vmid/status/shutdown")
            if echo "$stop_result" | grep -q '"data":'; then
                echo -e "${GREEN}    ✓ VM stopped${NC}"
            fi
            
            # Wait for shutdown
            sleep 5
            
            # Delete VM
            local delete_result=$(api_call "DELETE" "/nodes/${proxmox_node}/qemu/$vmid")
            if echo "$delete_result" | grep -q '"data":'; then
                echo -e "${GREEN}    ✓ VM deleted${NC}"
            else
                echo -e "${RED}    ✗ Failed to delete VM${NC}"
            fi
        else
            echo -e "${BLUE}  $name (ID: $vmid) not found, skipping...${NC}"
        fi
    done
    
    # Clean up configuration files
    echo -e "${YELLOW}🧹 Cleaning up configuration files...${NC}"
    local files_to_remove=(
        "./talos-configs"
        "./talos-secrets.yaml"
        "./kubeconfig"
    )
    
    for file in "${files_to_remove[@]}"; do
        if [ -e "$file" ]; then
            rm -rf "$file"
            echo -e "${GREEN}  ✓ Removed $file${NC}"
        else
            echo -e "${BLUE}  $file does not exist, skipping...${NC}"
        fi
    done
    
    echo ""
    echo -e "${GREEN}✅ Cleanup complete!${NC}"
    echo -e "${BLUE}All VMs and configuration files have been removed.${NC}"
    echo -e "${BLUE}You can now run '$0 deploy' to create a fresh cluster.${NC}"
}

# Function to show status
show_status() {
    echo -e "${CYAN}📊 Cluster Status${NC}"
    echo ""
    
    # Check configuration
    if [ ! -f "cluster.conf" ]; then
        echo -e "${RED}✗ Configuration file not found${NC}"
        exit 1
    fi
    
    parse_config
    
    # Check VMs
    echo -e "${YELLOW}VM Status:${NC}"
    local result=$(api_call "GET" "/cluster/resources?type=vm" 2>/dev/null)
    
    local vm_found=false
    for i in "${!VM_IDS[@]}"; do
        local vmid="${VM_IDS[$i]}"
        local name="${VM_NAMES[$i]}"
        
        if echo "$result" | grep -q "\"vmid\":$vmid"; then
            local status=$(echo "$result" | jq -r ".data[] | select(.vmid == $vmid) | .status" 2>/dev/null || echo "unknown")
            echo -e "  - $name (ID: $vmid): $status"
            vm_found=true
        fi
    done
    
    if [ "$vm_found" = false ]; then
        echo -e "  No cluster VMs found"
    fi
    
    # Check Kubernetes cluster
    if [ -f "kubeconfig" ]; then
        echo ""
        echo -e "${YELLOW}Kubernetes Status:${NC}"
        export KUBECONFIG="./kubeconfig"
        
        if kubectl get nodes --no-headers 2>/dev/null | grep -q "Ready"; then
            kubectl get nodes -o wide
        else
            echo -e "  Cluster not ready or not accessible"
        fi
        
        echo ""
        echo -e "${YELLOW}System Pods:${NC}"
        kubectl get pods -A 2>/dev/null || echo "  No pods found"
    else
        echo ""
        echo -e "${YELLOW}Kubernetes: Not configured${NC}"
    fi
}

# Function to parse command line arguments
parse_arguments() {
    local command="$1"
    shift
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_DELETE_EXISTING_VMS=true
                shift
                ;;
            --verbose)
                set -x
                shift
                ;;
            --dry-run)
                echo -e "${YELLOW}Dry run mode - no changes will be made${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                usage
                exit 1
                ;;
        esac
    done
    
    # Execute command
    case "$command" in
        "deploy")
            deploy_cluster
            ;;
        "cleanup")
            cleanup_cluster
            ;;
        "status")
            show_status
            ;;
        "help"|"--help"|"-h")
            usage
            ;;
        "")
            echo -e "${RED}✗ No command specified${NC}"
            usage
            exit 1
            ;;
        *)
            echo -e "${RED}✗ Unknown command: $command${NC}"
            usage
            exit 1
            ;;
    esac
}

# Main execution
main() {
    show_banner
    parse_arguments "$@"
}

# Run main function with all arguments
main "$@"
