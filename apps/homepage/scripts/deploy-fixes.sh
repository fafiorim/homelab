#!/bin/bash

# Quick deployment script for Homepage stability fixes
set -e

echo "🚀 Deploying Homepage Stability Fixes for Talos Kubernetes"
echo "========================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "manifests/homepage-complete-fixed.yaml" ]; then
    print_error "Please run this script from the homepage app directory"
    print_status "Expected to find: manifests/homepage-complete-fixed.yaml"
    exit 1
fi

echo
print_status "Step 1: Checking cluster connectivity..."
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi
print_success "Connected to cluster"

echo
print_status "Step 2: Checking current Homepage deployment..."
if kubectl get deployment homepage >/dev/null 2>&1; then
    print_warning "Existing Homepage deployment found"
    read -p "Do you want to remove it and deploy the fixed version? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Removing existing deployment..."
        kubectl delete -f manifests/homepage-complete.yaml --ignore-not-found=true
        print_success "Existing deployment removed"
    else
        print_status "Skipping deployment removal"
    fi
else
    print_status "No existing Homepage deployment found"
fi

echo
print_status "Step 3: Checking Metrics Server..."
if kubectl get deployment -n kube-system metrics-server >/dev/null 2>&1; then
    if kubectl top nodes >/dev/null 2>&1; then
        print_success "Metrics Server is working"
    else
        print_warning "Metrics Server exists but not working properly"
        read -p "Deploy Talos-optimized Metrics Server? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Deploying Talos-optimized Metrics Server..."
            kubectl apply -f manifests/metrics-server-talos-optimized.yaml
            print_status "Waiting for Metrics Server to be ready..."
            kubectl wait --for=condition=available deployment metrics-server -n kube-system --timeout=300s
            print_success "Metrics Server deployed"
        fi
    fi
else
    print_status "Deploying Metrics Server for Talos..."
    kubectl apply -f manifests/metrics-server-talos-optimized.yaml
    print_status "Waiting for Metrics Server to be ready..."
    kubectl wait --for=condition=available deployment metrics-server -n kube-system --timeout=300s
    print_success "Metrics Server deployed"
fi

echo
print_status "Step 4: Deploying fixed Homepage..."
kubectl apply -f manifests/homepage-complete-fixed.yaml
print_success "Homepage deployment applied"

print_status "Waiting for Homepage to be ready..."
kubectl wait --for=condition=available deployment homepage --timeout=300s
print_success "Homepage is ready"

echo
print_status "Step 5: Verifying deployment..."
RUNNING_PODS=$(kubectl get pods -l app.kubernetes.io/name=homepage --no-headers | grep -c "Running" || echo "0")
if [ "$RUNNING_PODS" -gt 0 ]; then
    print_success "$RUNNING_PODS Homepage pod(s) are running"
else
    print_error "No Homepage pods are running"
    print_status "Checking pod status..."
    kubectl get pods -l app.kubernetes.io/name=homepage
fi

echo
print_status "Step 6: Getting access information..."
NODE_PORT=$(kubectl get service homepage-nodeport -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo
print_success "Deployment completed successfully!"
echo
echo "📋 Access Information:"
echo "===================="
if [ -n "$NODE_PORT" ] && [ -n "$NODE_IP" ]; then
    echo "🌐 NodePort Access: http://$NODE_IP:$NODE_PORT"
    echo "🌐 External Access: http://10.10.21.200:$NODE_PORT"
fi
echo "🔄 Port Forward: kubectl port-forward service/homepage 8080:3000"
echo "📊 Pod Status: kubectl get pods -l app.kubernetes.io/name=homepage"
echo "📝 Logs: kubectl logs -l app.kubernetes.io/name=homepage --tail=50"

echo
echo "🔧 Troubleshooting:"
echo "==================="
echo "Run: ./scripts/troubleshoot-enhanced.sh"
echo
echo "🧪 Quick Test:"
echo "=============="
echo "curl http://$NODE_IP:$NODE_PORT"

echo
print_status "Deployment script completed!"