#!/bin/bash

# Talos Kubernetes Cluster Environment Setup
# Source this file to set up your environment for the cluster
#
# Usage:
#   source ./setup-env.sh
#   # or
#   . ./setup-env.sh

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set environment variables
export KUBECONFIG="${SCRIPT_DIR}/kubeconfig"
export TALOSCONFIG="${SCRIPT_DIR}/talos-configs/talosconfig"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}✅ Talos cluster environment configured!${NC}"
echo ""
echo -e "${BLUE}Environment variables set:${NC}"
echo -e "  KUBECONFIG=${KUBECONFIG}"
echo -e "  TALOSCONFIG=${TALOSCONFIG}"
echo ""
echo -e "${BLUE}You can now use:${NC}"
echo -e "  kubectl get nodes"
echo -e "  kubectl get pods -A"
echo -e "  talosctl get nodes"
echo ""

# Check if cluster is accessible
if command -v kubectl >/dev/null 2>&1; then
    if kubectl get nodes >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Cluster is accessible and ready!${NC}"
        echo ""
        echo -e "${BLUE}Current nodes:${NC}"
        kubectl get nodes
    else
        echo -e "${BLUE}ℹ️  Cluster may still be initializing...${NC}"
    fi
else
    echo -e "${BLUE}ℹ️  kubectl not found in PATH${NC}"
fi