#!/bin/bash

# Homelab GitOps Bootstrap Script
# This script handles the initial bootstrap that ArgoCD can't do alone

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🚀 Homelab GitOps Bootstrap${NC}"
echo -e "${BLUE}This script handles initial bootstrap dependencies${NC}"
echo ""

# Check if configuration exists
if [ ! -f "homelab.conf" ]; then
    echo -e "${RED}❌ homelab.conf not found!${NC}"
    echo -e "${YELLOW}Please copy homelab.conf.template to homelab.conf and fill in your values${NC}"
    exit 1
fi

# Load configuration
source homelab.conf

echo -e "${YELLOW}📋 Configuration loaded:${NC}"
echo -e "  Domain: ${DOMAIN}"
echo -e "  LoadBalancer IP: ${TRAEFIK_LOADBALANCER_IP}"
echo ""

# Function to wait for ArgoCD to be ready
wait_for_argocd() {
    echo -e "${YELLOW}⏳ Waiting for ArgoCD to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
    echo -e "${GREEN}✅ ArgoCD is ready${NC}"
}

# Function to bootstrap MetalLB (required before ArgoCD can manage it)
bootstrap_metallb() {
    echo -e "${YELLOW}🔧 Bootstrapping MetalLB...${NC}"
    
    # Install MetalLB CRDs and controllers
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
    
    # Wait for MetalLB to be ready
    echo -e "${YELLOW}⏳ Waiting for MetalLB to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app=metallb -n metallb-system --timeout=120s
    
    # Apply MetalLB configuration
    kubectl apply -f apps/metallb/config.yaml
    
    echo -e "${GREEN}✅ MetalLB bootstrapped${NC}"
}

# Function to create secrets that can't be in Git
create_secrets() {
    echo -e "${YELLOW}🔐 Creating secrets...${NC}"
    
    if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ "$CLOUDFLARE_API_TOKEN" = "your_cloudflare_api_token_here" ]; then
        echo -e "${RED}❌ Please set your CLOUDFLARE_API_TOKEN in homelab.conf${NC}"
        exit 1
    fi
    
    # Generate Cloudflare secret
    ENCODED_TOKEN=$(echo -n "$CLOUDFLARE_API_TOKEN" | base64)
    
    # Create secret YAML
    cat > /tmp/cloudflare-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token
  namespace: traefik-system
type: Opaque
data:
  CF_API_TOKEN: ${ENCODED_TOKEN}
EOF
    
    # Create namespace if it doesn't exist and apply secret
    kubectl create namespace traefik-system --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f /tmp/cloudflare-secret.yaml
    rm /tmp/cloudflare-secret.yaml
    
    echo -e "${GREEN}✅ Secrets created${NC}"
}

# Function to deploy ArgoCD applications
deploy_applications() {
    echo -e "${YELLOW}📦 Deploying ArgoCD applications...${NC}"
    
    # Deploy core infrastructure first
    echo -e "${BLUE}Deploying MetalLB...${NC}"
    kubectl apply -f apps/metallb/metallb-app.yaml
    
    echo -e "${BLUE}Deploying Traefik...${NC}"
    kubectl apply -f apps/traefik/traefik-app.yaml
    
    # Wait a moment for core infrastructure
    sleep 10
    
    # Deploy applications
    echo -e "${BLUE}Deploying applications...${NC}"
    find apps/ -name "*-app.yaml" -not -path "*/metallb/*" -not -path "*/traefik/*" -exec kubectl apply -f {} \;
    
    echo -e "${GREEN}✅ All applications deployed${NC}"
}

# Function to wait for applications to be ready
wait_for_applications() {
    echo -e "${YELLOW}⏳ Waiting for core applications to be ready...${NC}"
    
    # Check if pods are actually running (more reliable than ArgoCD health status)
    local max_attempts=20
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        # Check if Traefik pods are running
        local traefik_ready=$(kubectl get pods -n traefik-system -l app=traefik --no-headers 2>/dev/null | grep "1/1.*Running" | wc -l | tr -d ' ')
        
        # Check if Homepage pods are running  
        local homepage_ready=$(kubectl get pods -n homepage -l app=homepage --no-headers 2>/dev/null | grep "1/1.*Running" | wc -l | tr -d ' ')
        
        # Check LoadBalancer IP assignment
        local lb_ip=$(kubectl get svc traefik -n traefik-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        
        if [ "$traefik_ready" = "1" ] && [ "$homepage_ready" = "1" ] && [ "$lb_ip" = "$TRAEFIK_LOADBALANCER_IP" ]; then
            echo -e "${GREEN}✅ Core applications are running and ready${NC}"
            echo -e "${GREEN}  - Traefik: Running with LoadBalancer IP $lb_ip${NC}"
            echo -e "${GREEN}  - Homepage: Running and accessible${NC}"
            break
        fi
        
        echo -e "${BLUE}Attempt $((attempt+1))/$max_attempts - Traefik: $traefik_ready pods, Homepage: $homepage_ready pods, LB IP: ${lb_ip:-"pending"}${NC}"
        sleep 15
        ((attempt++))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        echo -e "${YELLOW}⚠️  Timeout waiting for applications, but they may still be starting${NC}"
    fi
    
    # Brief ArgoCD status check (but don't wait for it)
    echo -e "${BLUE}ArgoCD Health Status:${NC}"
    kubectl get applications -n argocd --no-headers | while read name sync health; do
        echo -e "  $name: $health"
    done
}

# Function to verify deployment
verify_deployment() {
    echo -e "${YELLOW}🔍 Verifying deployment...${NC}"
    
    # Check ArgoCD applications
    echo -e "${BLUE}ArgoCD Applications:${NC}"
    kubectl get applications -n argocd
    
    echo ""
    echo -e "${BLUE}LoadBalancer Services:${NC}"
    kubectl get svc -A --field-selector spec.type=LoadBalancer
    
    echo ""
    echo -e "${BLUE}Testing HTTPS endpoints:${NC}"
    
    # Test endpoints (with timeout)
    local endpoints=("https://homepage.${DOMAIN}" "https://argocd.${DOMAIN}")
    
    for endpoint in "${endpoints[@]}"; do
        if curl -k -s -o /dev/null -w "%{http_code}" --max-time 10 "$endpoint" | grep -q "200\|302"; then
            echo -e "  ✅ $endpoint"
        else
            echo -e "  ⏳ $endpoint (may still be starting)"
        fi
    done
}

# Function to get ArgoCD admin password
get_argocd_password() {
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "Run: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

# Function to show access information
show_access_info() {
    echo ""
    echo -e "${GREEN}🎉 Bootstrap complete!${NC}"
    echo ""
    echo -e "${YELLOW}🌐 Your services:${NC}"
    echo -e "  🏠 Homepage:    https://homepage.${DOMAIN}"
    echo -e "  🔧 ArgoCD:      https://argocd.${DOMAIN}"
    echo -e "  📊 Grafana:     https://grafana.${DOMAIN}"
    echo -e "  📈 Prometheus:  https://prometheus.${DOMAIN}"
    echo ""
    echo -e "${BLUE}💡 LoadBalancer IP: ${TRAEFIK_LOADBALANCER_IP}${NC}"
    echo -e "${BLUE}📊 Traefik Dashboard: http://${TRAEFIK_LOADBALANCER_IP}:8080${NC}"
    echo ""
    echo -e "${GREEN}🔐 Login Credentials:${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    
    # ArgoCD credentials
    local argocd_password=$(get_argocd_password)
    echo -e "${BLUE}🔧 ArgoCD:${NC}"
    echo -e "  URL:      https://argocd.${DOMAIN}"
    echo -e "  Username: ${GREEN}admin${NC}"
    echo -e "  Password: ${GREEN}${argocd_password}${NC}"
    echo ""
    
    # Grafana credentials
    echo -e "${BLUE}📊 Grafana:${NC}"
    echo -e "  URL:      https://grafana.${DOMAIN}"
    echo -e "  Username: ${GREEN}admin${NC}"
    echo -e "  Password: ${GREEN}admin123${NC}"
    echo ""
    
    # Prometheus (no auth)
    echo -e "${BLUE}📈 Prometheus:${NC}"
    echo -e "  URL:      https://prometheus.${DOMAIN}"
    echo -e "  Auth:     ${YELLOW}None required${NC}"
    echo ""
    
    # Homepage (no auth)
    echo -e "${BLUE}🏠 Homepage:${NC}"
    echo -e "  URL:      https://homepage.${DOMAIN}"
    echo -e "  Auth:     ${YELLOW}None required${NC}"
    echo ""
    
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}🔄 GitOps Active: All changes to GitHub will auto-sync!${NC}"
}

# Main execution
main() {
    wait_for_argocd
    bootstrap_metallb
    create_secrets
    deploy_applications
    wait_for_applications
    verify_deployment
    show_access_info
}

# Parse command line arguments
case "${1:-deploy}" in
    "bootstrap")
        bootstrap_metallb
        create_secrets
        ;;
    "deploy")
        main
        ;;
    "verify")
        verify_deployment
        ;;
    *)
        echo "Usage: $0 [bootstrap|deploy|verify]"
        echo ""
        echo "Commands:"
        echo "  bootstrap  - Only bootstrap dependencies and secrets"
        echo "  deploy     - Full deployment (default)"
        echo "  verify     - Verify current deployment"
        exit 1
        ;;
esac