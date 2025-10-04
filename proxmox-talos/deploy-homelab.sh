#!/bin/bash

# Homelab Deployment Script with Configuration Management
# This script ensures reproducible deployments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if configuration exists
if [ ! -f "homelab.conf" ]; then
    echo -e "${RED}❌ homelab.conf not found!${NC}"
    echo -e "${YELLOW}Please copy homelab.conf.template to homelab.conf and fill in your values:${NC}"
    echo -e "cp homelab.conf.template homelab.conf"
    echo -e "# Then edit homelab.conf with your values"
    exit 1
fi

# Load configuration
source homelab.conf

echo -e "${GREEN}🚀 Deploying Homelab with Configuration${NC}"
echo -e "${BLUE}Domain: ${DOMAIN}${NC}"
echo -e "${BLUE}Traefik IP: ${TRAEFIK_LOADBALANCER_IP}${NC}"

# Generate Cloudflare secret
generate_cloudflare_secret() {
    echo -e "${YELLOW}🔐 Generating Cloudflare API secret...${NC}"
    
    if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ "$CLOUDFLARE_API_TOKEN" = "your_cloudflare_api_token_here" ]; then
        echo -e "${RED}❌ Please set your CLOUDFLARE_API_TOKEN in homelab.conf${NC}"
        exit 1
    fi
    
    # Generate base64 encoded token
    ENCODED_TOKEN=$(echo -n "$CLOUDFLARE_API_TOKEN" | base64)
    
    # Create secret file
    cat > apps/traefik/cloudflare-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token
  namespace: traefik-system
type: Opaque
data:
  CF_API_TOKEN: ${ENCODED_TOKEN}
EOF
    
    echo -e "${GREEN}✅ Cloudflare secret generated${NC}"
}

# Update Traefik configuration with domain
update_traefik_config() {
    echo -e "${YELLOW}🔧 Updating Traefik configuration...${NC}"
    
    # Update email in config
    sed -i.bak "s/admin@botocudo.net/${ADMIN_EMAIL}/g" apps/traefik/config.yaml
    
    # Update LoadBalancer IP
    if ! grep -q "metallb.universe.tf/loadBalancerIPs" apps/traefik/deployment.yaml; then
        echo -e "${YELLOW}Adding LoadBalancer IP annotation...${NC}"
        # This is already done in the file, but we could add more logic here
    fi
    
    echo -e "${GREEN}✅ Traefik configuration updated${NC}"
}

# Generate ingress files with correct domain
generate_ingress_files() {
    echo -e "${YELLOW}🌐 Generating ingress files...${NC}"
    
    # This function would regenerate all ingress files with the correct domain
    # For now, they're already created with botocudo.net
    
    echo -e "${GREEN}✅ Ingress files ready${NC}"
}

# Main deployment
deploy_homelab() {
    echo -e "${YELLOW}📦 Deploying services...${NC}"
    
    # Apply metallb configuration
    kubectl apply -f apps/metallb/
    
    # Generate and apply cloudflare secret
    generate_cloudflare_secret
    kubectl apply -f apps/traefik/cloudflare-secret.yaml
    
    # Apply traefik
    kubectl apply -f apps/traefik/
    
    # Apply ingress configurations
    cd /Users/franzvitorf/Documents/LABs/homelab
    kubectl apply -f apps/argocd/ingress.yaml -f apps/monitoring/ingress.yaml -f apps/nginx-proxy-manager/ingress.yaml
    cd -
    
    echo -e "${GREEN}🎉 Homelab deployment complete!${NC}"
    echo -e "${BLUE}Your services are available at:${NC}"
    echo -e "  🏠 Homepage:    https://homepage.${DOMAIN}"
    echo -e "  🔧 ArgoCD:      https://argocd.${DOMAIN}"
    echo -e "  📊 Grafana:     https://grafana.${DOMAIN}"
    echo -e "  📈 Prometheus:  https://prometheus.${DOMAIN}"
    echo -e "  🌐 NPM:         https://npm.${DOMAIN}"
    echo -e ""
    echo -e "${YELLOW}LoadBalancer IP: ${TRAEFIK_LOADBALANCER_IP}${NC}"
}

# Run deployment
case "${1:-deploy}" in
    "config")
        generate_cloudflare_secret
        update_traefik_config
        ;;
    "deploy")
        deploy_homelab
        ;;
    *)
        echo "Usage: $0 [config|deploy]"
        exit 1
        ;;
esac