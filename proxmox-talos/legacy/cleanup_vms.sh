#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configuration
if [ ! -f "config.conf" ]; then
    echo -e "${RED}❌ ERROR: config.conf not found!${NC}"
    exit 1
fi

source config.conf

echo -e "${BLUE}🧹 Homelab VM Cleanup Script${NC}"
echo -e "${BLUE}==============================${NC}"

# Function to make Proxmox API calls
proxmox_api_call() {
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

# Function to stop VM
stop_vm() {
    local vmid=$1
    local name=$2
    
    echo -e "${YELLOW}Stopping VM $name (ID: $vmid)...${NC}"
    local response=$(proxmox_api_call "POST" "/nodes/${proxmox_node}/qemu/${vmid}/status/stop")
    if [[ $response == *"data"* ]]; then
        echo -e "${GREEN}✓ VM $name stopped${NC}"
        sleep 5  # Wait for VM to stop
        return 0
    else
        echo -e "${YELLOW}⚠ VM $name might already be stopped or doesn't exist${NC}"
        return 1
    fi
}

# Function to delete VM
delete_vm() {
    local vmid=$1
    local name=$2
    
    echo -e "${YELLOW}Deleting VM $name (ID: $vmid)...${NC}"
    
    # Force stop first
    echo -e "${BLUE}  Force stopping VM...${NC}"
    proxmox_api_call "POST" "/nodes/${proxmox_node}/qemu/${vmid}/status/stop" >/dev/null 2>&1
    sleep 3
    
    # Delete VM with force
    local response=$(proxmox_api_call "DELETE" "/nodes/${proxmox_node}/qemu/${vmid}?force=1&purge=1")
    if [[ $response == *"data"* ]]; then
        echo -e "${GREEN}✓ VM $name deleted${NC}"
        sleep 2  # Wait for cleanup
        return 0
    else
        echo -e "${RED}❌ Failed to delete VM $name${NC}"
        echo "Response: $response"
        return 1
    fi
}

# Function to check if VM exists
check_vm_exists() {
    local vmid=$1
    local response=$(proxmox_api_call "GET" "/nodes/${proxmox_node}/qemu/${vmid}/status/current")
    if [[ $response == *"vmid"* ]]; then
        return 0  # VM exists
    else
        return 1  # VM doesn't exist
    fi
}

# Function to clean orphaned VM config files
clean_orphaned_configs() {
    echo -e "${BLUE}Checking for orphaned VM configuration files...${NC}"
    
    # Check if config files exist on Proxmox node
    local vms=(
        "400:talos-control-plane"
        "411:talos-worker-01" 
        "412:talos-worker-02"
    )
    
    for vm_info in "${vms[@]}"; do
        IFS=':' read -r vmid name <<< "$vm_info"
        
        # Try to get VM config - if it returns error about config file not existing, 
        # we need to clean it up from the API perspective
        local config_response=$(proxmox_api_call "GET" "/nodes/${proxmox_node}/qemu/${vmid}/config" 2>/dev/null)
        if [[ $config_response == *"Configuration file"* ]] && [[ $config_response == *"does not exist"* ]]; then
            echo -e "${YELLOW}Found orphaned reference for VM $name (ID: $vmid)${NC}"
            # Force cleanup any remaining references
            proxmox_api_call "DELETE" "/nodes/${proxmox_node}/qemu/${vmid}?force=1&purge=1" >/dev/null 2>&1
        fi
    done
}

# Main cleanup function
cleanup_vms() {
    local vms_cleaned=0
    
    # VM IDs and names to clean up
    local vms=(
        "400:talos-control-plane"
        "411:talos-worker-01"
        "412:talos-worker-02"
    )
    
    echo -e "${BLUE}Checking for existing VMs...${NC}"
    
    for vm_info in "${vms[@]}"; do
        IFS=':' read -r vmid name <<< "$vm_info"
        
        if check_vm_exists "$vmid"; then
            echo -e "${YELLOW}Found VM: $name (ID: $vmid)${NC}"
            
            # Stop VM first
            stop_vm "$vmid" "$name"
            
            # Then delete VM
            if delete_vm "$vmid" "$name"; then
                ((vms_cleaned++))
            fi
        else
            echo -e "${GREEN}✓ VM $name (ID: $vmid) doesn't exist${NC}"
        fi
    done
    
    # Clean any orphaned configuration references
    echo ""
    clean_orphaned_configs
    
    echo ""
    if [ $vms_cleaned -gt 0 ]; then
        echo -e "${GREEN}✓ Cleanup completed! Removed $vms_cleaned VMs${NC}"
        echo -e "${BLUE}You can now run the deployment script${NC}"
    else
        echo -e "${GREEN}✓ No VMs found to clean up${NC}"
    fi
}

# Confirmation prompt
echo -e "${YELLOW}⚠ WARNING: This will delete the following VMs if they exist:${NC}"
echo -e "  - talos-control-plane (ID: 400)"
echo -e "  - talos-worker-01 (ID: 411)"
echo -e "  - talos-worker-02 (ID: 412)"
echo ""
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cleanup_vms
else
    echo -e "${BLUE}Cleanup cancelled${NC}"
    exit 0
fi