#!/bin/bash

# =============================================================================
# Post-Deployment Network Setup Script
# =============================================================================
# This script handles post-deployment network configuration and validation
# Run this after deployment to ensure proper connectivity
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

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

show_header() {
    echo -e "${BLUE}${BOLD}🔧 Post-Deployment Network Setup${NC}"
    echo ""
}

setup_network_routing() {
    log_info "Setting up network routing for MetalLB LoadBalancer access..."
    
    # Check if route already exists
    if netstat -rn | grep -q "10.10.21.200"; then
        log_info "MetalLB route already exists"
        netstat -rn | grep "10.10.21.200"
    else
        log_info "Adding network route for MetalLB LoadBalancer IP range..."
        log_warning "This requires sudo privileges"
        
        # Add route via the worker node (more stable than control plane)
        sudo route add -net 10.10.21.200/28 10.10.21.112
        
        if [ $? -eq 0 ]; then
            log_success "Network route added successfully"
        else
            log_error "Failed to add network route"
            return 1
        fi
    fi
}

fix_podsecurity_policies() {
    log_info "Configuring PodSecurity policies for system namespaces..."
    
    export KUBECONFIG=./kubeconfig
    
    # Fix MetalLB namespace
    kubectl label namespace metallb-system pod-security.kubernetes.io/enforce=privileged pod-security.kubernetes.io/audit=privileged pod-security.kubernetes.io/warn=privileged --overwrite
    
    # Fix Traefik namespace  
    kubectl label namespace traefik-system pod-security.kubernetes.io/enforce=privileged pod-security.kubernetes.io/audit=privileged pod-security.kubernetes.io/warn=privileged --overwrite
    
    log_success "PodSecurity policies configured"
}

restart_metallb_speakers() {
    log_info "Restarting MetalLB speakers to ensure proper operation..."
    
    export KUBECONFIG=./kubeconfig
    
    # Delete and let DaemonSet recreate them
    kubectl delete pods -n metallb-system -l component=speaker
    
    # Wait for speakers to restart
    log_info "Waiting for MetalLB speakers to restart..."
    sleep 15
    
    # Check speaker status
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local running_speakers=$(kubectl get pods -n metallb-system -l component=speaker --no-headers | grep -c "Running" || echo "0")
        if [ "$running_speakers" = "3" ]; then
            log_success "All MetalLB speakers are running"
            break
        fi
        
        log_info "Waiting for speakers... ($running_speakers/3 running)"
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "MetalLB speakers failed to start properly"
        kubectl get pods -n metallb-system -l component=speaker
        return 1
    fi
}

validate_connectivity() {
    log_info "Validating service connectivity..."
    
    # Test LoadBalancer IP
    log_info "Testing LoadBalancer IP connectivity..."
    if nc -zv 10.10.21.201 80 2>/dev/null; then
        log_success "LoadBalancer port 80 accessible"
    else
        log_error "LoadBalancer port 80 not accessible"
    fi
    
    # Test DNS resolution
    log_info "Testing DNS resolution..."
    if nslookup homepage.botocudo.net > /dev/null 2>&1; then
        log_success "DNS resolution working"
    else
        log_warning "DNS resolution may have issues"
    fi
    
    # Test HTTP connectivity
    log_info "Testing HTTP service access..."
    if curl -m 5 -s -o /dev/null -w "%{http_code}" http://homepage.botocudo.net | grep -q "200\|404"; then
        log_success "HTTP services accessible"
    else
        log_warning "HTTP services may not be fully ready"
    fi
}

show_service_status() {
    log_info "Service Status Summary:"
    echo ""
    
    export KUBECONFIG=./kubeconfig
    
    # Show LoadBalancer services
    echo -e "${BLUE}LoadBalancer Services:${NC}"
    kubectl get svc -A --field-selector spec.type=LoadBalancer
    echo ""
    
    # Show ingress
    echo -e "${BLUE}Ingress Rules:${NC}"
    kubectl get ingress -A
    echo ""
    
    # Show service URLs
    echo -e "${BLUE}Service URLs:${NC}"
    echo -e "🏠 Homepage:    http://homepage.botocudo.net"
    echo -e "📊 Grafana:     http://grafana.botocudo.net"  
    echo -e "📈 Prometheus:  http://prometheus.botocudo.net"
    echo -e "🔧 ArgoCD:      https://argocd.botocudo.net"
    echo -e "📋 Traefik:     http://10.10.21.201:8080/dashboard/"
    echo ""
}

main() {
    show_header
    
    setup_network_routing
    fix_podsecurity_policies
    restart_metallb_speakers
    validate_connectivity
    show_service_status
    
    echo ""
    log_success "Post-deployment setup completed!"
    echo ""
    log_info "If services are still not accessible:"
    log_info "1. Wait 5-10 minutes for all pods to fully start"
    log_info "2. Check ArgoCD for application sync status"
    log_info "3. Verify Traefik ingress rules are properly configured"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi