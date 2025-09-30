#!/bin/bash

# Talos Cluster Configuration Script
# Configures the deployed VMs as a Talos Kubernetes cluster

set -e

# Fixed IP addresses
CP_IP="10.10.21.110"
WORKER1_IP="10.10.21.111"
WORKER2_IP="10.10.21.112"

CLUSTER_NAME="talos-homelab"
CLUSTER_ENDPOINT="https://$CP_IP:6443"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Talos Cluster Configuration${NC}"
echo "==============================="
echo "Control Plane: $CP_IP"
echo "Worker 1: $WORKER1_IP"
echo "Worker 2: $WORKER2_IP"
echo "Cluster Endpoint: $CLUSTER_ENDPOINT"
echo ""

# Step 1: Verify connectivity
echo -e "${BLUE}🔍 Step 1: Verifying connectivity to all nodes...${NC}"
all_reachable=true
for ip in $CP_IP $WORKER1_IP $WORKER2_IP; do
    if ping -c 2 -W 3 $ip >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $ip - Reachable${NC}"
    else
        echo -e "${RED}❌ $ip - Not reachable${NC}"
        all_reachable=false
    fi
done

if [ "$all_reachable" != true ]; then
    echo -e "${RED}❌ Cannot reach all nodes. Please check DHCP reservations and VM status.${NC}"
    exit 1
fi

# Step 2: Generate machine configurations
echo ""
echo -e "${BLUE}📋 Step 2: Generating machine configurations...${NC}"
mkdir -p _out

talosctl gen config $CLUSTER_NAME $CLUSTER_ENDPOINT \
    --output-dir _out \
    --with-examples=false \
    --with-docs=false

echo -e "${GREEN}✅ Machine configurations generated${NC}"

# Step 3: Apply configurations to nodes
echo ""
echo -e "${BLUE}🚀 Step 3: Applying configurations to nodes...${NC}"

# Control Plane
echo "Configuring Control Plane ($CP_IP)..."
talosctl apply-config --insecure \
    --nodes $CP_IP \
    --file _out/controlplane.yaml

# Workers
echo "Configuring Worker 1 ($WORKER1_IP)..."
talosctl apply-config --insecure \
    --nodes $WORKER1_IP \
    --file _out/worker.yaml

echo "Configuring Worker 2 ($WORKER2_IP)..."
talosctl apply-config --insecure \
    --nodes $WORKER2_IP \
    --file _out/worker.yaml

echo -e "${GREEN}✅ All nodes configured${NC}"

# Step 4: Wait for nodes to be ready
echo ""
echo -e "${BLUE}⏳ Step 4: Waiting for nodes to apply configurations (90 seconds)...${NC}"
sleep 90

# Step 5: Set up talosctl context
echo ""
echo -e "${BLUE}🔧 Step 5: Setting up talosctl context...${NC}"
talosctl config endpoint $CP_IP
talosctl config node $CP_IP

# Step 6: Bootstrap the cluster
echo ""
echo -e "${BLUE}🚀 Step 6: Bootstrapping the cluster...${NC}"
max_attempts=3
attempt=1

while [ $attempt -le $max_attempts ]; do
    echo "Bootstrap attempt $attempt/$max_attempts..."
    if talosctl bootstrap --nodes $CP_IP; then
        echo -e "${GREEN}✅ Cluster bootstrapped successfully${NC}"
        break
    else
        echo -e "${RED}❌ Bootstrap attempt $attempt failed${NC}"
        if [ $attempt -lt $max_attempts ]; then
            echo -e "${YELLOW}⏳ Waiting 30 seconds before retry...${NC}"
            sleep 30
        fi
        attempt=$((attempt + 1))
    fi
done

if [ $attempt -gt $max_attempts ]; then
    echo -e "${RED}❌ Failed to bootstrap cluster after $max_attempts attempts${NC}"
    exit 1
fi

# Step 7: Wait for Kubernetes API
echo ""
echo -e "${BLUE}⏳ Step 7: Waiting for Kubernetes API to be ready...${NC}"
max_wait=300
wait_time=0

while [ $wait_time -lt $max_wait ]; do
    if talosctl health --nodes $CP_IP >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Kubernetes API is ready${NC}"
        break
    fi
    echo "Waiting for API... ($wait_time/${max_wait}s)"
    sleep 10
    wait_time=$((wait_time + 10))
done

if [ $wait_time -ge $max_wait ]; then
    echo -e "${RED}❌ Kubernetes API did not become ready in time${NC}"
    exit 1
fi

# Step 8: Configure kubectl
echo ""
echo -e "${BLUE}🔧 Step 8: Configuring kubectl...${NC}"
talosctl kubeconfig .
export KUBECONFIG=$(pwd)/kubeconfig

# Step 9: Wait for all nodes to be ready
echo ""
echo -e "${BLUE}⏳ Step 9: Waiting for all nodes to join the cluster...${NC}"
max_wait=300
wait_time=0

while [ $wait_time -lt $max_wait ]; do
    ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep " Ready " | wc -l | tr -d ' ')
    if [ "$ready_nodes" = "3" ]; then
        echo -e "${GREEN}✅ All 3 nodes are ready${NC}"
        break
    fi
    echo "Ready nodes: $ready_nodes/3 ($wait_time/${max_wait}s)"
    sleep 15
    wait_time=$((wait_time + 15))
done

# Step 10: Final status
echo ""
echo -e "${BLUE}🎉 Step 10: Cluster Status${NC}"
echo "=========================="
echo ""
echo "Cluster Nodes:"
kubectl get nodes -o wide

echo ""
echo "Cluster Info:"
kubectl cluster-info

echo ""
echo -e "${GREEN}✅ Talos cluster is ready!${NC}"
echo ""
echo -e "${BLUE}📋 Connection Info:${NC}"
echo "Cluster Endpoint: $CLUSTER_ENDPOINT"
echo "Kubectl Config: $(pwd)/kubeconfig"
echo ""
echo -e "${BLUE}📋 Node IPs (Fixed):${NC}"
echo "Control Plane: $CP_IP"
echo "Worker 1: $WORKER1_IP"
echo "Worker 2: $WORKER2_IP"