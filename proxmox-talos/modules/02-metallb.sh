#!/bin/bash

# =============================================================================
# Module 02: MetalLB LoadBalancer
# =============================================================================
# This module handles:
# - MetalLB installation and configuration
# - IP address pool setup
# - L2 advertisement configuration
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Module configuration
MODULE_NAME="MetalLB"
MODULE_VERSION="1.0.0"
METALLB_VERSION="v0.14.8"
REQUIRED_TOOLS=("kubectl")

# Load configuration
CONFIG_FILE="config.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Configuration file $CONFIG_FILE not found${NC}"
    exit 1
fi

source "$CONFIG_FILE"

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_module() {
    echo -e "${CYAN}🔧 Module: $MODULE_NAME v$MODULE_VERSION${NC}"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool '$tool' not found"
            exit 1
        fi
    done
    
    # Check kubeconfig
    if [ ! -f "kubeconfig" ]; then
        log_error "kubeconfig file not found. Run infrastructure module first."
        exit 1
    fi
    
    export KUBECONFIG="./kubeconfig"
    
    # Check cluster connectivity
    if ! kubectl get nodes &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

check_existing_installation() {
    log_info "Checking for existing MetalLB installation..."
    
    if kubectl get namespace metallb-system &> /dev/null; then
        log_warning "MetalLB namespace already exists"
        if kubectl get pods -n metallb-system --no-headers 2>/dev/null | grep -q "Running"; then
            local running_pods=$(kubectl get pods -n metallb-system --no-headers | grep -c "Running" || echo "0")
            log_info "Found $running_pods running MetalLB pods"
            
            # Check if configuration exists
            if kubectl get ipaddresspool -n metallb-system &> /dev/null; then
                log_success "MetalLB already installed and configured"
                return 0
            fi
        fi
    fi
    
    return 1
}

install_metallb() {
    log_info "Installing MetalLB $METALLB_VERSION..."
    
    # Apply MetalLB manifests
    kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/$METALLB_VERSION/config/manifests/metallb-native.yaml"
    
    log_info "Waiting for MetalLB pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=metallb -n metallb-system --timeout=300s
    
    log_success "MetalLB installed successfully"
}

configure_metallb() {
    log_info "Configuring MetalLB IP address pool..."
    
    # Create IP address pool configuration
    cat > /tmp/metallb-config.yaml << EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - ${METALLB_IP_RANGE}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF
    
    # Apply configuration
    kubectl apply -f /tmp/metallb-config.yaml
    rm -f /tmp/metallb-config.yaml
    
    log_success "MetalLB configuration applied"
}

verify_deployment() {
    log_info "Verifying MetalLB deployment..."
    
    # Check pods
    local ready_pods=$(kubectl get pods -n metallb-system --no-headers | grep -c "Running" || echo "0")
    if [ "$ready_pods" -lt 2 ]; then
        log_error "MetalLB pods are not running properly"
        kubectl get pods -n metallb-system
        return 1
    fi
    
    # Check configuration
    if ! kubectl get ipaddresspool default-pool -n metallb-system &> /dev/null; then
        log_error "MetalLB IP address pool not found"
        return 1
    fi
    
    if ! kubectl get l2advertisement default -n metallb-system &> /dev/null; then
        log_error "MetalLB L2 advertisement not found"
        return 1
    fi
    
    log_success "MetalLB verification completed"
    
    # Display deployment info
    echo ""
    echo -e "${CYAN}🎉 MetalLB Deployment Complete!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${GREEN}Namespace:${NC} metallb-system"
    echo -e "${GREEN}IP Range:${NC} ${METALLB_IP_RANGE}"
    echo ""
    echo -e "${GREEN}Pods:${NC}"
    kubectl get pods -n metallb-system
    echo ""
    echo -e "${GREEN}Configuration:${NC}"
    kubectl get ipaddresspool,l2advertisement -n metallb-system
    echo ""
}

test_loadbalancer() {
    log_info "Testing LoadBalancer functionality..."
    
    # Create a test service
    cat > /tmp/test-lb.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-lb
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-lb
  template:
    metadata:
      labels:
        app: test-lb
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-lb
  namespace: default
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: test-lb
EOF
    
    kubectl apply -f /tmp/test-lb.yaml
    
    log_info "Waiting for LoadBalancer IP assignment..."
    local max_wait=60
    local waited=0
    while [ $waited -lt $max_wait ]; do
        local lb_ip=$(kubectl get svc test-lb -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null || echo "")
        if [[ "$lb_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        fi
        sleep 2
        waited=$((waited + 2))
    done
    
    local lb_ip=$(kubectl get svc test-lb -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
    if [[ "$lb_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_success "LoadBalancer test successful - IP: $lb_ip"
    else
        log_error "LoadBalancer test failed - no IP assigned"
        kubectl describe svc test-lb
        return 1
    fi
    
    # Cleanup test resources
    kubectl delete -f /tmp/test-lb.yaml
    rm -f /tmp/test-lb.yaml
    
    log_success "LoadBalancer test completed and cleaned up"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    log_module
    echo ""
    
    check_prerequisites
    
    if check_existing_installation; then
        log_info "MetalLB already installed, skipping installation"
    else
        install_metallb
        configure_metallb
    fi
    
    verify_deployment
    test_loadbalancer
    
    log_success "Module $MODULE_NAME completed successfully!"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi