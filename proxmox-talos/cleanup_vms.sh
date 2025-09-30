#!/bin/bash

# Cleanup script for Laternfly Talos cluster VMs
# This script stops and deletes the VMs created by deploy_laternfly_cluster.sh

# Proxmox API Configuration
PROXMOX_URL="https://10.10.21.31:8006/api2/json"
TOKEN_ID="terraform@pve!terraform-token"
TOKEN_SECRET="50b62f0b-e403-4697-be3b-9ca62a4df295"
NODE="firefly"

# VM IDs
CONTROL_PLANE_VMID=400
WORKER_01_VMID=411
WORKER_02_VMID=412

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
            -H "Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "${PROXMOX_URL}${endpoint}"
    else
        curl -k -X "$method" \
            -H "Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}" \
            "${PROXMOX_URL}${endpoint}"
    fi
}

# Function to stop and delete VM
delete_vm() {
    local vmid=$1
    local name=$2
    
    echo -e "${YELLOW}Processing VM: $name (ID: $vmid)${NC}"
    
    # Check if VM exists
    local result=$(api_call "GET" "/cluster/resources?type=vm" 2>/dev/null)
    if ! echo "$result" | grep -q "\"vmid\":$vmid"; then
        echo -e "${BLUE}  VM $name (ID: $vmid) does not exist, skipping...${NC}"
        return 0
    fi
    
    # Stop VM first
    echo -e "${BLUE}  Stopping VM...${NC}"
    local stop_result=$(api_call "POST" "/nodes/$NODE/qemu/$vmid/status/shutdown")
    if echo "$stop_result" | grep -q '"data":'; then
        echo -e "${GREEN}  ✓ VM $name stopped${NC}"
    else
        echo -e "${YELLOW}  VM $name may already be stopped${NC}"
    fi
    
    # Wait for shutdown
    echo -e "${BLUE}  Waiting for shutdown to complete...${NC}"
    sleep 10
    
    # Delete VM
    echo -e "${BLUE}  Deleting VM...${NC}"
    local delete_result=$(api_call "DELETE" "/nodes/$NODE/qemu/$vmid")
    if echo "$delete_result" | grep -q '"data":'; then
        echo -e "${GREEN}  ✓ VM $name deleted successfully${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed to delete VM $name${NC}"
        echo "  Error: $delete_result"
        return 1
    fi
}

# Function to clean up configuration files
cleanup_configs() {
    echo -e "${YELLOW}Cleaning up configuration files...${NC}"
    
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
}

# Main execution
echo -e "${RED}=== Laternfly Talos Cluster Cleanup ===${NC}"
echo -e "This will delete the following VMs:"
echo -e "  - talos-control-plane (ID: $CONTROL_PLANE_VMID)"
echo -e "  - talos-worker-01 (ID: $WORKER_01_VMID)"
echo -e "  - talos-worker-02 (ID: $WORKER_02_VMID)"
echo ""

# Confirmation
read -p "Are you sure you want to proceed? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}Cleanup cancelled.${NC}"
    exit 0
fi

echo ""

# Delete VMs
echo -e "${YELLOW}Deleting VMs...${NC}"
delete_vm $CONTROL_PLANE_VMID "talos-control-plane"
delete_vm $WORKER_01_VMID "talos-worker-01"
delete_vm $WORKER_02_VMID "talos-worker-02"

echo ""

# Clean up configuration files
cleanup_configs

echo ""
echo -e "${GREEN}=== Cleanup Complete ===${NC}"
echo -e "All VMs and configuration files have been removed."
echo -e "You can now run ./deploy_laternfly_cluster.sh to create a fresh cluster."
