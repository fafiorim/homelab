#!/bin/bash

# Homepage Deployment Test Script
# This script tests the deployment process from scratch to ensure replicability

set -e

NAMESPACE="default"
APP_NAME="homepage"
NODEPORT=30090

echo "🚀 Homepage Deployment Test Script"
echo "=================================="

# Check prerequisites
echo "1. Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    echo "[ERROR] kubectl is not installed or not in PATH"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "[ERROR] Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "[SUCCESS] Prerequisites met"

# Clean up any existing deployment
echo "2. Cleaning up existing deployment..."
if kubectl get deployment $APP_NAME &> /dev/null; then
    echo "[INFO] Removing existing Homepage deployment..."
    kubectl delete -f /Users/franzvitorf/Documents/LABs/homelab/homelab/apps/homepage/manifests/homepage-complete.yaml || true
    sleep 10
fi

# Deploy fresh
echo "3. Deploying Homepage..."
kubectl apply -f /Users/franzvitorf/Documents/LABs/homelab/homelab/apps/homepage/manifests/homepage-complete.yaml

# Wait for deployment
echo "4. Waiting for deployment to be ready..."
kubectl rollout status deployment $APP_NAME --timeout=300s

# Verify pods
echo "5. Verifying pods..."
kubectl get pods -l app.kubernetes.io/name=$APP_NAME

# Test connectivity
echo "6. Testing connectivity..."
NODES=(10.10.21.200 10.10.21.211 10.10.21.212)
for node in "${NODES[@]}"; do
    echo "Testing http://$node:$NODEPORT"
    if curl -s -o /dev/null -w "%{http_code}" http://$node:$NODEPORT | grep -q "200"; then
        echo "[SUCCESS] Node $node is accessible"
    else
        echo "[WARNING] Node $node may not be accessible"
    fi
done

echo ""
echo "✅ Deployment test completed!"
echo "🌐 Access your Homepage at: http://10.10.21.200:$NODEPORT"
echo ""
echo "📋 Backup access points:"
echo "   • http://10.10.21.211:$NODEPORT"
echo "   • http://10.10.21.212:$NODEPORT"