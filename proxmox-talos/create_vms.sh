#!/bin/bash

# Proxmox API Configuration
PROXMOX_URL="https://10.10.21.31:8006/api2/json"
TOKEN_ID="terraform@pve!terraform-token"
TOKEN_SECRET="50b62f0b-e403-4697-be3b-9ca62a4df295"
NODE="firefly"
STORAGE="local-lvm"
ISO_STORAGE="local"
TALOS_ISO="talos-v1.11.1-amd64.iso"
NETWORK_BRIDGE="vmbr0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Function to create VM
create_vm() {
    local vmid=$1
    local name=$2
    local cores=$3
    local memory=$4
    local macaddr=$5
    local ip_comment=$6
    
    echo -e "${YELLOW}Creating VM: $name (ID: $vmid)${NC}"
    
    # Create VM configuration
    local vm_config="{
        \"vmid\": $vmid,
        \"name\": \"$name\",
        \"cores\": $cores,
        \"sockets\": 1,
        \"memory\": $memory,
        \"boot\": \"order=ide2;scsi0\",
        \"scsihw\": \"virtio-scsi-pci\",
        \"agent\": 0,
        \"ostype\": \"l26\",
        \"cpu\": \"host\",
        \"numa\": false,
        \"hotplug\": \"network,disk,usb\",
        \"net0\": \"virtio,bridge=$NETWORK_BRIDGE,macaddr=$macaddr,firewall=0\",
        \"scsi0\": \"$STORAGE:20,format=raw\",
        \"ide2\": \"$ISO_STORAGE:iso/$TALOS_ISO,media=cdrom\",
        \"tags\": \"talos,$(if [[ $name == *control* ]]; then echo 'control-plane'; else echo 'worker'; fi)\"
    }"
    
    # Create the VM
    local result=$(api_call "POST" "/nodes/$NODE/qemu" "$vm_config")
    
    if echo "$result" | grep -q '"data":'; then
        echo -e "${GREEN}✓ VM $name created successfully${NC}"
        echo -e "  - VM ID: $vmid"
        echo -e "  - IP: $ip_comment"
        echo -e "  - MAC: $macaddr"
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
    
    local result=$(api_call "POST" "/nodes/$NODE/qemu/$vmid/status/start")
    
    if echo "$result" | grep -q '"data":'; then
        echo -e "${GREEN}✓ VM $name started successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to start VM $name${NC}"
        echo "Error: $result"
        return 1
    fi
}

# Main execution
echo -e "${GREEN}=== Proxmox VM Creation Script ===${NC}"
echo -e "Node: $NODE"
echo -e "Storage: $STORAGE"
echo -e "ISO: $TALOS_ISO"
echo ""

# Check if Talos ISO exists
echo -e "${YELLOW}Checking if Talos ISO exists...${NC}"
iso_check=$(api_call "GET" "/nodes/$NODE/storage/$ISO_STORAGE/content")
if echo "$iso_check" | grep -q "$TALOS_ISO"; then
    echo -e "${GREEN}✓ Talos ISO found${NC}"
else
    echo -e "${RED}✗ Talos ISO not found. Please upload $TALOS_ISO to $ISO_STORAGE storage${NC}"
    exit 1
fi

echo ""

# Create VMs
echo -e "${YELLOW}Creating 3 Talos VMs...${NC}"
echo ""

# Control Plane VM
create_vm 300 "talos-control-plane" 4 4096 "bc:24:11:82:9f:fb" "10.10.21.110"
echo ""

# Worker Node 01
create_vm 310 "talos-worker-01" 2 2048 "bc:24:11:51:6f:4d" "10.10.21.111"
echo ""

# Worker Node 02
create_vm 311 "talos-worker-02" 2 2048 "87:33:11:82:9f:3c" "10.10.21.112"
echo ""

# Start all VMs
echo -e "${YELLOW}Starting all VMs...${NC}"
start_vm 300 "talos-control-plane"
start_vm 310 "talos-worker-01"
start_vm 311 "talos-worker-02"

echo ""
echo -e "${GREEN}=== VM Creation Complete ===${NC}"
echo -e "Control Plane: VM ID 300 (10.10.21.110)"
echo -e "Worker 01:     VM ID 310 (10.10.21.111)"
echo -e "Worker 02:     VM ID 311 (10.10.21.112)"
echo ""
echo -e "${YELLOW}Note: VMs are created and started. Configure Talos machine configs for network setup.${NC}"
