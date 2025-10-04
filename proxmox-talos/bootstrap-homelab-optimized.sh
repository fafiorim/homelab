#!/bin/bash

# Optimized Homelab GitOps Bootstrap
# Reduces kubectl calls for better performance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
CONFIG_FILE="homelab.conf"

echo -e "${GREEN}🚀 Homelab GitOps Bootstrap${NC}"
echo -e "${BLUE}This script handles initial bootstrap dependencies${NC}"

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Configuration file $CONFIG_FILE not found${NC}"
    exit 1
fi

source "$CONFIG_FILE"
echo ""
echo -e "${BLUE}📋 Configuration loaded:${NC}"
echo -e "${BLUE}  Domain: ${DOMAIN}${NC}"
echo -e "${BLUE}  LoadBalancer IP: ${TRAEFIK_LOADBALANCER_IP}${NC}"
echo ""

# Fast deployment mode check
FAST_DEPLOY=${FAST_DEPLOY:-0}
if [ "$FAST_DEPLOY" = "1" ]; then
    echo -e "${BLUE}🚀 Fast deployment mode enabled${NC}"
fi

# Check if ArgoCD is ready (single call)
wait_for_argocd() {
    echo -e "${YELLOW}⏳ Waiting for ArgoCD to be ready...${NC}"
    if ! kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s 2>/dev/null; then
        echo -e "${RED}❌ ArgoCD not found or not ready${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ ArgoCD is ready${NC}"
}

# Bootstrap MetalLB with optimized approach
bootstrap_metallb() {
    echo -e "${BLUE}🔧 Bootstrapping MetalLB...${NC}"
    
    # Apply MetalLB and config in single batch
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
    
    # Wait for MetalLB to be ready with single wait command
    echo -e "${YELLOW}⏳ Waiting for MetalLB to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app=metallb -n metallb-system --timeout=120s
    
    # Apply MetalLB configuration
    kubectl apply -f apps/metallb/config.yaml
    echo -e "${GREEN}✅ MetalLB bootstrapped${NC}"
}

# Create secrets with batch operations
create_secrets() {
    echo -e "${BLUE}🔐 Creating secrets...${NC}"
    
    # Create namespace and secret in batch
    kubectl create namespace traefik-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Generate Cloudflare secret
    cat > /tmp/cloudflare-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token
  namespace: traefik-system
type: Opaque
data:
  CF_API_TOKEN: $(echo -n "$CLOUDFLARE_API_TOKEN" | base64 -w 0)
EOF
    
    kubectl apply -f /tmp/cloudflare-secret.yaml
    rm -f /tmp/cloudflare-secret.yaml
    echo -e "${GREEN}✅ Secrets created${NC}"
}

# Deploy applications with batch operations
deploy_applications() {
    echo -e "${BLUE}📦 Deploying ArgoCD applications...${NC}"
    
    # Collect all application files and apply in fewer batches
    local app_files=(
        "apps/metallb/metallb-app.yaml"
        "apps/traefik/traefik-app.yaml"
    )
    
    # Find additional app files
    while IFS= read -r -d '' file; do
        app_files+=("$file")
    done < <(find apps/ -name "*-app.yaml" -not -path "*/metallb/*" -not -path "*/traefik/*" -print0)
    
    # Apply all applications in single command
    kubectl apply -f "${app_files[@]}"
    
    echo -e "${GREEN}✅ All applications deployed${NC}"
}

# Optimized wait function with fewer kubectl calls
wait_for_applications() {
    echo -e "${YELLOW}⏳ Waiting for core applications to be ready...${NC}"
    
    local max_attempts=8
    local sleep_time=10
    local attempt=0
    
    if [ "$FAST_DEPLOY" = "1" ]; then
        max_attempts=4
        sleep_time=5
    fi
    
    while [ $attempt -lt $max_attempts ]; do
        # Single kubectl call to get all pod and service info
        local cluster_info=$(kubectl get pods,svc -A -o json 2>/dev/null || echo '{"items":[]}')
        
        # Parse results using jq for efficiency
        local traefik_ready=$(echo "$cluster_info" | jq -r '.items[] | select(.kind=="Pod" and .metadata.namespace=="traefik-system" and .metadata.labels.app=="traefik" and .status.phase=="Running" and (.status.containerStatuses[]?.ready//false)) | .metadata.name' | wc -l)
        
        local homepage_ready=$(echo "$cluster_info" | jq -r '.items[] | select(.kind=="Pod" and .metadata.namespace=="homepage" and .metadata.labels.app=="homepage" and .status.phase=="Running" and (.status.containerStatuses[]?.ready//false)) | .metadata.name' | wc -l)
        
        local lb_ip=$(echo "$cluster_info" | jq -r '.items[] | select(.kind=="Service" and .metadata.name=="traefik" and .metadata.namespace=="traefik-system") | .status.loadBalancer.ingress[0].ip // ""' 2>/dev/null)
        
        if [ "$traefik_ready" = "1" ] && [ "$homepage_ready" = "1" ] && [ "$lb_ip" = "$TRAEFIK_LOADBALANCER_IP" ]; then
            echo -e "${GREEN}✅ Core applications are running and ready${NC}"
            echo -e "${GREEN}  - Traefik: Running with LoadBalancer IP $lb_ip${NC}"
            echo -e "${GREEN}  - Homepage: Running and accessible${NC}"
            break
        fi
        
        echo -e "${BLUE}Attempt $((attempt+1))/$max_attempts - Traefik: $traefik_ready pods, Homepage: $homepage_ready pods, LB IP: ${lb_ip:-"pending"}${NC}"
        sleep $sleep_time
        attempt=$((attempt+1))
    done
}

# Optimized verification with batch operations
verify_deployment() {
    echo -e "${BLUE}🔍 Verifying deployment...${NC}"
    
    # Get all info in single call
    local apps_info=$(kubectl get applications -n argocd -o json 2>/dev/null || echo '{"items":[]}')
    local services_info=$(kubectl get svc -A --field-selector spec.type=LoadBalancer -o json 2>/dev/null || echo '{"items":[]}')
    
    # Display ArgoCD applications status
    echo -e "${BLUE}ArgoCD Applications:${NC}"
    printf "%-12s %-12s %-12s\n" "NAME" "SYNC STATUS" "HEALTH STATUS"
    echo "$apps_info" | jq -r '.items[] | "\(.metadata.name) \(.status.sync.status // "Unknown") \(.status.health.status // "Unknown")"' | while read name sync health; do
        if [[ "$health" == "Healthy" ]]; then
            printf "${GREEN}%-12s %-12s %-12s${NC}\n" "$name" "$sync" "$health"
        else
            printf "${YELLOW}%-12s %-12s %-12s${NC}\n" "$name" "$sync" "$health"
        fi
    done
    
    echo ""
    echo -e "${BLUE}LoadBalancer Services:${NC}"
    echo "$services_info" | jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name) \(.spec.type) \(.spec.clusterIP) \(.status.loadBalancer.ingress[0].ip // "Pending") \(.spec.ports | map("\(.port):\(.nodePort)") | join(","))"' | \
    while read namespace name type cluster_ip external_ip ports; do
        printf "%-15s %-10s %-12s %-15s %-15s %s\n" "$namespace" "$name" "$type" "$cluster_ip" "$external_ip" "$ports"
    done
    
    echo ""
    # Quick endpoint tests (parallel)
    echo -e "${BLUE}Testing HTTPS endpoints:${NC}"
    {
        curl -s -o /dev/null -w "Homepage: %{http_code}\n" --max-time 5 "https://homepage.$DOMAIN" &
        curl -s -o /dev/null -w "ArgoCD: %{http_code}\n" --max-time 5 "https://argocd.$DOMAIN" &
        wait
    } | while read result; do
        if [[ "$result" =~ 200|302 ]]; then
            echo -e "  ${GREEN}✅ $result${NC}"
        else
            echo -e "  ${YELLOW}⏳ $result (may still be starting)${NC}"
        fi
    done
}

# Optimized cleanup with parallel operations
delete_applications() {
    echo -e "${YELLOW}🗑️  Deleting applications...${NC}"
    
    # Parallel cleanup operations
    {
        kubectl delete applications --all -n argocd --ignore-not-found=true &
        kubectl delete namespace homepage monitoring --ignore-not-found=true &
        wait
    }
    
    # Quick verification
    echo -e "${YELLOW}⏳ Verifying cleanup...${NC}"
    for i in {1..10}; do
        local remaining=$(kubectl get applications -n argocd --ignore-not-found=true 2>/dev/null | wc -l)
        local remaining_ns=$(kubectl get namespace homepage monitoring --ignore-not-found=true 2>/dev/null | wc -l)
        
        if [ "$remaining" -le 1 ] && [ "$remaining_ns" -le 1 ]; then
            echo -e "${GREEN}✅ Applications and namespaces cleaned up${NC}"
            break
        fi
        
        echo "   Attempt $i/10: Waiting for cleanup..."
        sleep 2
    done
    
    echo -e "${GREEN}✅ Application cleanup complete${NC}"
}

# Display credentials (single call for ArgoCD password)
show_credentials() {
    local argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "Check manually: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d")
    
    echo -e "${GREEN}🔐 Login Credentials:${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}🔧 ArgoCD:${NC}"
    echo -e "  URL:      https://argocd.$DOMAIN"
    echo -e "  Username: admin"
    echo -e "  Password: $argocd_password"
    echo ""
    echo -e "${BLUE}📊 Grafana:${NC}"
    echo -e "  URL:      https://grafana.$DOMAIN"
    echo -e "  Username: admin"
    echo -e "  Password: admin123"
    echo ""
    echo -e "${BLUE}📈 Prometheus:${NC}"
    echo -e "  URL:      https://prometheus.$DOMAIN"
    echo -e "  Auth:     None required"
    echo ""
    echo -e "${BLUE}🏠 Homepage:${NC}"
    echo -e "  URL:      https://homepage.$DOMAIN"
    echo -e "  Auth:     None required"
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
}

# Main execution function
main() {
    bootstrap_metallb
    create_secrets
    deploy_applications
    wait_for_applications
    verify_deployment
    
    echo ""
    echo -e "${GREEN}🎉 Bootstrap complete!${NC}"
    echo ""
    echo -e "${GREEN}🌐 Your services:${NC}"
    echo -e "  🏠 Homepage:    https://homepage.$DOMAIN"
    echo -e "  🔧 ArgoCD:      https://argocd.$DOMAIN"
    echo -e "  📊 Grafana:     https://grafana.$DOMAIN"
    echo -e "  📈 Prometheus:  https://prometheus.$DOMAIN"
    echo ""
    echo -e "${BLUE}💡 LoadBalancer IP: $TRAEFIK_LOADBALANCER_IP${NC}"
    echo -e "${BLUE}📊 Traefik Dashboard: http://$TRAEFIK_LOADBALANCER_IP:8080${NC}"
    echo ""
    
    show_credentials
    echo ""
    echo -e "${GREEN}🔄 GitOps Active: All changes to GitHub will auto-sync!${NC}"
}

# Parse command line arguments
case "${1:-deploy}" in
    "bootstrap")
        bootstrap_metallb
        create_secrets
        ;;
    "deploy")
        wait_for_argocd
        main
        ;;
    "delete")
        delete_applications
        ;;
    "redeploy")
        delete_applications
        echo ""
        echo -e "${GREEN}🔄 Starting fresh deployment...${NC}"
        sleep 2
        wait_for_argocd
        main
        ;;
    "fast-deploy")
        export FAST_DEPLOY=1
        echo -e "${BLUE}🚀 Fast deployment mode enabled${NC}"
        wait_for_argocd
        main
        ;;
    "fast-redeploy")
        export FAST_DEPLOY=1
        echo -e "${BLUE}🚀 Fast redeploy mode enabled${NC}"
        delete_applications
        echo ""
        echo -e "${GREEN}🔄 Starting fast fresh deployment...${NC}"
        sleep 1
        wait_for_argocd
        main
        ;;
    "verify")
        verify_deployment
        ;;
    *)
        echo "Usage: $0 [bootstrap|deploy|delete|redeploy|fast-deploy|fast-redeploy|verify]"
        echo ""
        echo "Commands:"
        echo "  bootstrap      - Only bootstrap dependencies and secrets"
        echo "  deploy         - Full deployment (default)"
        echo "  delete         - Delete all applications and clean up"
        echo "  redeploy       - Delete all applications and redeploy fresh"
        echo "  fast-deploy    - Quick deployment with shorter waits and batch operations"
        echo "  fast-redeploy  - Quick delete and redeploy with optimizations"
        echo "  verify         - Verify current deployment"
        echo ""
        echo "Optimizations:"
        echo "  - Batch kubectl operations for better performance"
        echo "  - Parallel operations where possible"
        echo "  - Reduced API calls using JSON parsing"
        echo "  - Faster polling intervals in fast mode"
        exit 1
        ;;
esac