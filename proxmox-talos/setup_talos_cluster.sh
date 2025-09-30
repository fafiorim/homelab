#!/bin/bash

# Talos Cluster Setup Script
# This script configures a Talos Kubernetes cluster named "laternfly"
# with 1 control plane (VM 400) and 2 workers (VMs 411, 412)

# Cluster Configuration
CLUSTER_NAME="laternfly"
CONTROL_PLANE_IP="10.10.21.110"
WORKER_01_IP="10.10.21.111"
WORKER_02_IP="10.10.21.112"
CLUSTER_ENDPOINT="https://10.10.21.110:6443"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if talosctl is installed
check_talosctl() {
    if ! command_exists talosctl; then
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
    talosctl gen config "$CLUSTER_NAME" "$CLUSTER_ENDPOINT" \
        --output-dir ./talos-configs \
        --with-secrets ./talos-secrets.yaml \
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
    talosctl apply-config --insecure --nodes "$CONTROL_PLANE_IP" --file ./talos-configs/controlplane.yaml
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Control plane configuration applied${NC}"
    else
        echo -e "${RED}✗ Failed to apply control plane configuration${NC}"
        exit 1
    fi
    
    # Apply worker configs
    echo -e "${BLUE}Applying worker configuration (VM 411)...${NC}"
    talosctl apply-config --insecure --nodes "$WORKER_01_IP" --file ./talos-configs/worker.yaml
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Worker 01 configuration applied${NC}"
    else
        echo -e "${RED}✗ Failed to apply worker 01 configuration${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Applying worker configuration (VM 412)...${NC}"
    talosctl apply-config --insecure --nodes "$WORKER_02_IP" --file ./talos-configs/worker.yaml
    
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
    talosctl --talosconfig="$TALOSCONFIG" config endpoint "$CONTROL_PLANE_IP"
    
    # Bootstrap the cluster
    talosctl --talosconfig="$TALOSCONFIG" bootstrap --nodes "$CONTROL_PLANE_IP"
    
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
    
    # Get kubeconfig
    talosctl --talosconfig="$TALOSCONFIG" kubeconfig .
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Kubeconfig retrieved successfully${NC}"
        echo -e "  - Kubeconfig file: ./kubeconfig"
        echo ""
        echo -e "${YELLOW}To use kubectl:${NC}"
        echo "  export KUBECONFIG=./kubeconfig"
        echo "  kubectl get nodes"
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
    
    # Check nodes
    echo -e "${BLUE}Checking cluster nodes:${NC}"
    kubectl get nodes -o wide
    
    echo ""
    echo -e "${BLUE}Checking cluster pods:${NC}"
    kubectl get pods -A
    
    echo ""
    echo -e "${BLUE}Checking cluster services:${NC}"
    kubectl get svc -A
}

# Function to display cluster information
display_info() {
    echo ""
    echo -e "${GREEN}=== Talos Cluster 'laternfly' Setup Complete ===${NC}"
    echo ""
    echo -e "${BLUE}Cluster Information:${NC}"
    echo -e "  - Cluster Name: $CLUSTER_NAME"
    echo -e "  - Control Plane: $CONTROL_PLANE_IP (VM 400)"
    echo -e "  - Worker 01: $WORKER_01_IP (VM 411)"
    echo -e "  - Worker 02: $WORKER_02_IP (VM 412)"
    echo -e "  - API Endpoint: $CLUSTER_ENDPOINT"
    echo ""
    echo -e "${BLUE}Configuration Files:${NC}"
    echo -e "  - Talos Config: ./talos-configs/talosconfig"
    echo -e "  - Kubeconfig: ./kubeconfig"
    echo -e "  - Secrets: ./talos-secrets.yaml"
    echo ""
    echo -e "${BLUE}Usage:${NC}"
    echo -e "  # Use kubectl"
    echo -e "  export KUBECONFIG=./kubeconfig"
    echo -e "  kubectl get nodes"
    echo ""
    echo -e "  # Use talosctl"
    echo -e "  export TALOSCONFIG=./talos-configs/talosconfig"
    echo -e "  talosctl get nodes"
    echo ""
    echo -e "${YELLOW}Note: Keep the configuration files secure!${NC}"
}

# Main execution
echo -e "${GREEN}=== Talos Kubernetes Cluster Setup ===${NC}"
echo -e "Cluster Name: $CLUSTER_NAME"
echo -e "Control Plane: $CONTROL_PLANE_IP (VM 400)"
echo -e "Workers: $WORKER_01_IP (VM 411), $WORKER_02_IP (VM 412)"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
check_talosctl

# Create config directory
mkdir -p ./talos-configs

# Generate configurations
generate_configs

echo ""
echo -e "${YELLOW}Waiting for VMs to be ready...${NC}"
echo -e "${BLUE}Please ensure the VMs are running and accessible before continuing.${NC}"
echo -e "Press Enter to continue or Ctrl+C to cancel..."
read -r

# Apply configurations
apply_configs

echo ""
echo -e "${YELLOW}Waiting for nodes to initialize...${NC}"
sleep 60

# Bootstrap cluster
bootstrap_cluster

# Get kubeconfig
get_kubeconfig

# Verify cluster
verify_cluster

# Display final information
display_info

echo ""
echo -e "${GREEN}🎉 Talos cluster 'laternfly' is ready!${NC}"
