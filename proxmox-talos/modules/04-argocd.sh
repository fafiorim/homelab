#!/bin/bash

# =============================================================================
# Module 04: ArgoCD GitOps Controller
# =============================================================================
# This module handles:
# - ArgoCD installation via Helm
# - ArgoCD configuration for ingress
# - Repository access setup
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
MODULE_NAME="ArgoCD"
MODULE_VERSION="1.0.0"
ARGOCD_CHART_VERSION="8.5.8"
REQUIRED_TOOLS=("kubectl" "helm")

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../cluster.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Configuration file $CONFIG_FILE not found${NC}"
    exit 1
fi

source "$CONFIG_FILE"

# Map lowercase variables to uppercase for consistency
DOMAIN="$domain"

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
    echo -e "${CYAN}🔄 Module: $MODULE_NAME v$MODULE_VERSION${NC}"
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
    
    # Check Traefik
    if ! kubectl get pods -n traefik-system --no-headers 2>/dev/null | grep -q "Running"; then
        log_error "Traefik is not running. Run Traefik module first."
        exit 1
    fi
    
    # Check if Traefik has LoadBalancer IP
    local traefik_ip=$(kubectl get svc traefik -n traefik-system -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null || echo "")
    if [[ ! "$traefik_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Traefik LoadBalancer IP not available"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

check_existing_installation() {
    log_info "Checking for existing ArgoCD installation..."
    
    if kubectl get namespace argocd &> /dev/null; then
        log_warning "ArgoCD namespace already exists"
        if helm list -n argocd | grep -q "argocd"; then
            if kubectl get pods -n argocd --no-headers 2>/dev/null | grep -q "Running"; then
                local running_pods=$(kubectl get pods -n argocd --no-headers | grep -c "Running" || echo "0")
                log_info "Found $running_pods running ArgoCD pods"
                log_success "ArgoCD already installed via Helm"
                return 0
            fi
        fi
    fi
    
    return 1
}

setup_helm() {
    log_info "Setting up Helm repository..."
    
    # Add ArgoCD Helm repository
    if ! helm repo list | grep -q "argo.*https://argoproj.github.io/argo-helm"; then
        helm repo add argo https://argoproj.github.io/argo-helm
    fi
    
    helm repo update
    
    log_success "Helm repository configured"
}

create_namespace() {
    log_info "Creating ArgoCD namespace..."
    
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "ArgoCD namespace created"
}

install_argocd() {
    log_info "Installing ArgoCD via Helm..."
    
    # Install ArgoCD with custom configuration
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --version "$ARGOCD_CHART_VERSION" \
        --set server.service.type=ClusterIP \
        --set configs.params."server.insecure"=true \
        --set configs.params."server.grpc.web"=true \
        --set server.ingress.enabled=false \
        --set dex.enabled=true \
        --set notifications.enabled=true \
        --set applicationSet.enabled=true \
        --set server.extraArgs[0]="--insecure" \
        --wait --timeout=600s
    
    log_success "ArgoCD installed successfully"
}

configure_argocd() {
    log_info "Configuring ArgoCD..."
    
    # Set ArgoCD server URL
    kubectl patch configmap argocd-cm -n argocd --patch="{\"data\":{\"url\":\"https://argocd.$DOMAIN\"}}"
    
    # Configure ArgoCD for ingress
    kubectl patch configmap argocd-cmd-params-cm -n argocd --patch='{"data":{"server.insecure":"true","server.enable.grpc.web":"true"}}'
    
    # Restart ArgoCD server to apply changes
    kubectl rollout restart deployment argocd-server -n argocd
    kubectl rollout status deployment argocd-server -n argocd --timeout=300s
    
    log_success "ArgoCD configured"
}

create_ingress() {
    log_info "Creating ArgoCD ingress..."
    
    cat > /tmp/argocd-ingress.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.tls.certresolver: letsencrypt
    traefik.ingress.kubernetes.io/redirect-scheme: https
spec:
  ingressClassName: traefik
  rules:
  - host: argocd.$DOMAIN
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
EOF
    
    kubectl apply -f /tmp/argocd-ingress.yaml
    rm -f /tmp/argocd-ingress.yaml
    
    log_success "ArgoCD ingress created"
}

get_admin_password() {
    log_info "Retrieving ArgoCD admin password..."
    
    local admin_password=""
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
        if [ -n "$admin_password" ]; then
            break
        fi
        ((attempt++))
        sleep 5
    done
    
    if [ -z "$admin_password" ]; then
        log_error "Could not retrieve ArgoCD admin password"
        return 1
    fi
    
    # Store password in a file for later use
    echo "$admin_password" > .argocd-admin-password
    chmod 600 .argocd-admin-password
    
    log_success "ArgoCD admin password retrieved"
}

verify_deployment() {
    log_info "Verifying ArgoCD deployment..."
    
    # Check pods
    local ready_pods=$(kubectl get pods -n argocd --no-headers | grep -c "Running" || echo "0")
    if [ "$ready_pods" -lt 4 ]; then
        log_error "ArgoCD pods are not running properly"
        kubectl get pods -n argocd
        return 1
    fi
    
    # Check service
    if ! kubectl get svc argocd-server -n argocd &> /dev/null; then
        log_error "ArgoCD server service not found"
        return 1
    fi
    
    # Check ingress
    if ! kubectl get ingress argocd-server-ingress -n argocd &> /dev/null; then
        log_error "ArgoCD ingress not found"
        return 1
    fi
    
    # Test HTTPS connectivity
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if curl -k -s -o /dev/null -w "%{http_code}" "https://argocd.$DOMAIN" | grep -q "200"; then
            log_success "ArgoCD is accessible via HTTPS"
            break
        fi
        ((attempt++))
        sleep 10
        if [ $attempt -eq $max_attempts ]; then
            log_warning "ArgoCD HTTPS access test failed, but this might be due to DNS propagation"
        fi
    done
    
    log_success "ArgoCD verification completed"
    
    # Get admin password
    get_admin_password
    
    # Display deployment info
    local admin_password=$(cat .argocd-admin-password 2>/dev/null || echo "Failed to retrieve")
    
    echo ""
    echo -e "${CYAN}🎉 ArgoCD Deployment Complete!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${GREEN}Namespace:${NC} argocd"
    echo -e "${GREEN}URL:${NC} https://argocd.$DOMAIN"
    echo -e "${GREEN}Username:${NC} admin"
    echo -e "${GREEN}Password:${NC} $admin_password"
    echo ""
    echo -e "${GREEN}Services:${NC}"
    kubectl get svc -n argocd
    echo ""
    echo -e "${GREEN}Pods:${NC}"
    kubectl get pods -n argocd
    echo ""
    echo -e "${GREEN}Ingress:${NC}"
    kubectl get ingress -n argocd
    echo ""
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    log_module
    echo ""
    
    check_prerequisites
    
    if check_existing_installation; then
        log_info "ArgoCD already installed, skipping installation"
        get_admin_password
        verify_deployment
    else
        setup_helm
        create_namespace
        install_argocd
        configure_argocd
        create_ingress
        verify_deployment
    fi
    
    log_success "Module $MODULE_NAME completed successfully!"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi