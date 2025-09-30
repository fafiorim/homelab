#!/bin/bash

# Talos Cluster Cleanup Script
# Destroys the Terraform-managed VMs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🗑️  Talos Cluster Cleanup${NC}"
echo "========================="
echo ""
echo -e "${YELLOW}⚠️  This will destroy all VMs in the cluster!${NC}"
echo -e "${YELLOW}Are you sure you want to continue? (y/N)${NC}"
read -r response

if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo -e "${GREEN}✅ Cleanup cancelled${NC}"
    exit 0
fi

# Check if we're in the right directory
if [ ! -d "terraform" ]; then
    echo -e "${RED}❌ terraform directory not found. Please run from the project root.${NC}"
    exit 1
fi

cd terraform

echo ""
echo -e "${BLUE}🗑️  Destroying VMs...${NC}"
if terraform destroy -auto-approve; then
    echo -e "${GREEN}✅ All VMs destroyed successfully${NC}"
else
    echo -e "${RED}❌ Cleanup failed${NC}"
    exit 1
fi

cd ..

# Clean up local files
echo ""
echo -e "${BLUE}🧹 Cleaning up local files...${NC}"
rm -rf _out/
rm -f kubeconfig
rm -f talosconfig

echo -e "${GREEN}✅ Cleanup complete!${NC}"