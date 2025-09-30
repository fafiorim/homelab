#!/bin/bash

# Talos Cluster Deployment using Terraform + Proxmox Provider
# This script deploys a Talos Kubernetes cluster with fixed MAC addresses

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Talos Cluster Deployment with Terraform${NC}"
echo "=============================================="
echo ""
echo -e "${YELLOW}📋 Cluster Configuration:${NC}"
echo "Control Plane: 10.10.21.110 (MAC: bc:24:11:82:9f:fb)"
echo "Worker 1: 10.10.21.111 (MAC: bc:24:11:51:6f:4d)"
echo "Worker 2: 10.10.21.112 (MAC: bc:24:11:e3:7a:2c)"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Make sure you have DHCP reservations configured!${NC}"
echo ""

# Step 1: Check if we're in the right directory
if [ ! -d "terraform" ]; then
    echo -e "${RED}❌ terraform directory not found. Please run from the project root.${NC}"
    exit 1
fi

cd terraform

# Step 2: Initialize Terraform
echo -e "${BLUE}🔧 Step 1: Initializing Terraform...${NC}"
if terraform init; then
    echo -e "${GREEN}✅ Terraform initialized${NC}"
else
    echo -e "${RED}❌ Terraform initialization failed${NC}"
    exit 1
fi

# Step 3: Validate configuration
echo ""
echo -e "${BLUE}🔍 Step 2: Validating Terraform configuration...${NC}"
if terraform validate; then
    echo -e "${GREEN}✅ Configuration is valid${NC}"
else
    echo -e "${RED}❌ Configuration validation failed${NC}"
    exit 1
fi

# Step 4: Plan deployment
echo ""
echo -e "${BLUE}📋 Step 3: Planning deployment...${NC}"
if terraform plan -out=tfplan; then
    echo -e "${GREEN}✅ Plan created successfully${NC}"
else
    echo -e "${RED}❌ Planning failed${NC}"
    exit 1
fi

# Step 5: Apply deployment
echo ""
echo -e "${BLUE}🚀 Step 4: Deploying VMs...${NC}"
echo -e "${YELLOW}This will create the VMs on Proxmox. Continue? (y/N)${NC}"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    if terraform apply tfplan; then
        echo -e "${GREEN}✅ VMs deployed successfully!${NC}"
    else
        echo -e "${RED}❌ Deployment failed${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⏸️  Deployment cancelled${NC}"
    exit 0
fi

# Step 6: Show outputs
echo ""
echo -e "${BLUE}📊 Step 5: Deployment Summary${NC}"
terraform output

# Step 7: Wait for VMs to boot
echo ""
echo -e "${BLUE}⏳ Step 6: Waiting for VMs to boot (60 seconds)...${NC}"
sleep 60

# Step 8: Test connectivity
echo ""
echo -e "${BLUE}🔍 Step 7: Testing connectivity...${NC}"
ips=("10.10.21.110" "10.10.21.111" "10.10.21.112")
names=("Control Plane" "Worker 1" "Worker 2")
all_reachable=true

for i in "${!ips[@]}"; do
    ip="${ips[$i]}"
    name="${names[$i]}"
    if ping -c 2 -W 3 "$ip" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $name ($ip) - Reachable${NC}"
    else
        echo -e "${RED}❌ $name ($ip) - Not reachable${NC}"
        all_reachable=false
    fi
done

echo ""
if [ "$all_reachable" = true ]; then
    echo -e "${GREEN}🎉 All VMs are reachable! Ready for Talos configuration.${NC}"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "1. Configure the cluster: ./configure-cluster.sh"
    echo "2. Or run talosctl commands manually"
else
    echo -e "${YELLOW}⚠️  Some VMs are not reachable.${NC}"
    echo ""
    echo -e "${BLUE}💡 Troubleshooting:${NC}"
    echo "1. Check DHCP reservations are configured"
    echo "2. Wait a few more minutes for VMs to boot"
    echo "3. Verify network connectivity"
    echo ""
    echo -e "${BLUE}Expected DHCP reservations:${NC}"
    echo "bc:24:11:82:9f:fb → 10.10.21.110"
    echo "bc:24:11:51:6f:4d → 10.10.21.111"
    echo "bc:24:11:e3:7a:2c → 10.10.21.112"
fi

cd ..