#!/bin/bash

# Homepage Troubleshooting Script for Talos Kubernetes
# This script helps diagnose and fix common Homepage deployment issues

set -e

echo "🔍 Homepage Troubleshooting Script for Talos Kubernetes"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

print_status "Starting troubleshooting checks..."

echo
echo "1. Checking Kubernetes cluster connectivity..."
if kubectl cluster-info >/dev/null 2>&1; then
    print_success "Kubernetes cluster is accessible"
else
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

echo
echo "2. Checking Homepage pods status..."
HOMEPAGE_PODS=$(kubectl get pods -l app.kubernetes.io/name=homepage --no-headers 2>/dev/null | wc -l)
if [ "$HOMEPAGE_PODS" -gt 0 ]; then
    print_status "Found $HOMEPAGE_PODS Homepage pod(s)"
    kubectl get pods -l app.kubernetes.io/name=homepage
    
    # Check pod status
    RUNNING_PODS=$(kubectl get pods -l app.kubernetes.io/name=homepage --no-headers | grep -c "Running" || echo "0")
    if [ "$RUNNING_PODS" -gt 0 ]; then
        print_success "$RUNNING_PODS pod(s) are running"
    else
        print_error "No Homepage pods are running"
        echo "Checking pod events and logs..."
        kubectl describe pods -l app.kubernetes.io/name=homepage
    fi
else
    print_error "No Homepage pods found"
fi

echo
echo "3. Checking Homepage services..."
kubectl get services -l app.kubernetes.io/name=homepage 2>/dev/null || print_error "No Homepage services found"

echo
echo "4. Checking RBAC permissions..."
kubectl get clusterrole homepage >/dev/null 2>&1 && print_success "ClusterRole found" || print_error "ClusterRole not found"
kubectl get clusterrolebinding homepage >/dev/null 2>&1 && print_success "ClusterRoleBinding found" || print_error "ClusterRoleBinding not found"
kubectl get serviceaccount homepage >/dev/null 2>&1 && print_success "ServiceAccount found" || print_error "ServiceAccount not found"

echo
echo "5. Checking Metrics Server..."
METRICS_PODS=$(kubectl get pods -n kube-system -l k8s-app=metrics-server --no-headers 2>/dev/null | wc -l)
if [ "$METRICS_PODS" -gt 0 ]; then
    METRICS_RUNNING=$(kubectl get pods -n kube-system -l k8s-app=metrics-server --no-headers | grep -c "Running" || echo "0")
    if [ "$METRICS_RUNNING" -gt 0 ]; then
        print_success "Metrics Server is running"
        # Test if metrics are working
        if kubectl top nodes >/dev/null 2>&1; then
            print_success "Metrics Server is working correctly"
        else
            print_warning "Metrics Server is running but not providing metrics"
            print_status "This might be due to TLS issues with Talos"
        fi
    else
        print_error "Metrics Server pods are not running"
        kubectl get pods -n kube-system -l k8s-app=metrics-server
    fi
else
    print_error "Metrics Server not found - this will cause resource widget issues"
fi

echo
echo "6. Testing Homepage API endpoints..."
HOMEPAGE_POD=$(kubectl get pods -l app.kubernetes.io/name=homepage --no-headers | head -1 | awk '{print $1}')
if [ -n "$HOMEPAGE_POD" ]; then
    print_status "Testing API endpoint via pod: $HOMEPAGE_POD"
    if kubectl exec "$HOMEPAGE_POD" -- wget -q -O - http://localhost:3000/api/ping 2>/dev/null | grep -q "pong"; then
        print_success "Homepage API is responding"
    else
        print_error "Homepage API is not responding"
    fi
else
    print_warning "No Homepage pod available for API testing"
fi

echo
echo "7. Checking NodePort service accessibility..."
NODE_PORT=$(kubectl get service homepage-nodeport -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
if [ -n "$NODE_PORT" ]; then
    print_status "NodePort service is configured on port: $NODE_PORT"
    
    # Get a node IP
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    if [ -n "$NODE_IP" ]; then
        print_status "Testing accessibility via node: $NODE_IP:$NODE_PORT"
        # Note: This test might fail from within the cluster due to network policies
        print_status "Try accessing: http://$NODE_IP:$NODE_PORT"
    fi
else
    print_error "NodePort service not found"
fi

echo
echo "8. Checking for common configuration issues..."

# Check if Homepage is trying to access Docker
if kubectl get configmap homepage -o yaml | grep -q "docker"; then
    print_warning "Docker configuration detected - ensure DISABLE_DOCKER=true in deployment"
fi

# Check resource limits
MEMORY_LIMIT=$(kubectl get deployment homepage -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null)
if [ "$MEMORY_LIMIT" = "512Mi" ] && [ "$(echo "$MEMORY_LIMIT" | sed 's/Mi//')" -lt 1024 ]; then
    print_warning "Memory limit might be too low for stable operation"
fi

echo
echo "9. Recent events related to Homepage..."
kubectl get events --field-selector involvedObject.name=homepage --sort-by='.lastTimestamp' | tail -10

echo
echo "================== TROUBLESHOOTING SUMMARY =================="

echo
echo "🔧 Quick Fixes:"
echo "1. If pods are crashing:"
echo "   kubectl delete pod -l app.kubernetes.io/name=homepage"
echo
echo "2. If metrics are failing:"
echo "   kubectl apply -f metrics-server-talos-optimized.yaml"
echo
echo "3. If API errors persist:"
echo "   kubectl apply -f homepage-complete-fixed.yaml"
echo
echo "4. Check logs:"
echo "   kubectl logs -l app.kubernetes.io/name=homepage --tail=100"
echo
echo "5. Force restart:"
echo "   kubectl rollout restart deployment homepage"

echo
echo "📋 Configuration Tips for Talos:"
echo "- Ensure metrics-server has --kubelet-insecure-tls flag"
echo "- Use resource widgets sparingly until metrics-server is stable" 
echo "- Pin Homepage to a stable version (not :latest)"
echo "- Increase memory limits if pods are getting OOMKilled"
echo "- Use multiple replicas for better availability"

echo
print_status "Troubleshooting complete!"