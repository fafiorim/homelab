#!/bin/bash

# =============================================================================
# Module 05: Applications Deployment via ArgoCD
# =============================================================================
# This module handles:
# - Deploy all applications via ArgoCD
# - Verify application health and sync status
# - Ensure all services are accessible
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
MODULE_NAME="Applications"
MODULE_VERSION="1.0.0"
REQUIRED_TOOLS=("kubectl")

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../cluster.conf"
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
    echo -e "${CYAN}📦 Module: $MODULE_NAME v$MODULE_VERSION${NC}"
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
    
    # Check ArgoCD
    if ! kubectl get pods -n argocd --no-headers 2>/dev/null | grep -q "Running"; then
        log_error "ArgoCD is not running. Run ArgoCD module first."
        exit 1
    fi
    
    # Check apps directory
    if [ ! -d "apps" ]; then
        log_error "Apps directory not found. Ensure the apps directory exists with application manifests."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

get_application_files() {
    log_info "Discovering application files..." >&2
    
    local app_files=()
    
    # Find all *-app.yaml files in the apps directory
    while IFS= read -r -d '' file; do
        app_files+=("$file")
    done < <(find apps/ -name "*-app.yaml" -print0 2>/dev/null)
    
    if [ ${#app_files[@]} -eq 0 ]; then
        log_error "No application files found in apps directory" >&2
        exit 1
    fi
    
    echo "${app_files[@]}"
}

deploy_applications() {
    log_info "Deploying applications via ArgoCD..."
    
    local app_files=($(get_application_files))
    local deployed_apps=()
    
    for app_file in "${app_files[@]}"; do
        local app_name=$(basename "$app_file" -app.yaml)
        log_info "Deploying application: $app_name"
        
        kubectl apply -f "$app_file"
        deployed_apps+=("$app_name")
        
        # Small delay between deployments
        sleep 2
    done
    
    log_success "All applications deployed: ${deployed_apps[*]}"
    
    # Wait for ArgoCD to process the applications
    log_info "Waiting for ArgoCD to process applications..."
    sleep 15
}

wait_for_applications() {
    log_info "Waiting for applications to be healthy..."
    
    local max_wait=600  # 10 minutes
    local wait_time=0
    local check_interval=30
    
    while [ $wait_time -lt $max_wait ]; do
        local all_healthy=true
        local app_status=""
        
        # Get application status
        if ! app_status=$(kubectl get applications -n argocd -o json 2>/dev/null); then
            log_warning "Failed to get application status, retrying..."
            sleep $check_interval
            wait_time=$((wait_time + check_interval))
            continue
        fi
        
        # Check each application
        local app_names=($(echo "$app_status" | jq -r '.items[].metadata.name' 2>/dev/null))
        
        if [ ${#app_names[@]} -eq 0 ]; then
            log_warning "No applications found, waiting..."
            all_healthy=false
        else
            for app_name in "${app_names[@]}"; do
                local sync_status=$(echo "$app_status" | jq -r ".items[] | select(.metadata.name==\"$app_name\") | .status.sync.status" 2>/dev/null)
                local health_status=$(echo "$app_status" | jq -r ".items[] | select(.metadata.name==\"$app_name\") | .status.health.status" 2>/dev/null)
                
                if [ "$sync_status" != "Synced" ] || ([ "$health_status" != "Healthy" ] && [ "$health_status" != "Progressing" ]); then
                    log_info "Application $app_name: sync=$sync_status, health=$health_status"
                    all_healthy=false
                fi
            done
        fi
        
        if [ "$all_healthy" = true ]; then
            log_success "All applications are healthy"
            break
        fi
        
        log_info "Waiting for applications to become healthy... ($wait_time/$max_wait seconds)"
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    done
    
    if [ $wait_time -ge $max_wait ]; then
        log_warning "Timeout reached, some applications may still be starting"
    fi
}

verify_services() {
    log_info "Verifying service accessibility..."
    
    # List of expected services
    local services=("homepage" "grafana" "prometheus")
    local working_services=()
    local failed_services=()
    
    for service in "${services[@]}"; do
        local url="https://$service.$DOMAIN"
        local http_code=$(curl -k -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
        
        if [[ "$http_code" =~ ^[23] ]]; then
            log_success "$service is accessible ($http_code)"
            working_services+=("$service")
        else
            log_warning "$service is not accessible ($http_code)"
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_warning "Some services are not yet accessible: ${failed_services[*]}"
        log_info "This is normal during initial deployment. Services may take additional time to start."
    fi
}

get_service_credentials() {
    log_info "Retrieving service credentials..."
    
    local credentials_file="service-credentials.txt"
    
    # Get ArgoCD admin password
    local argocd_password=""
    if kubectl get secret -n argocd argocd-initial-admin-secret &>/dev/null; then
        argocd_password=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Unable to decode")
    fi
    
    # Get LoadBalancer IP for Traefik dashboard
    local traefik_ip=$(kubectl get svc traefik -n traefik-system -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null || echo "N/A")
    
    # Create enhanced credentials file with all services
    cat > "$credentials_file" << EOF
🔐 HOMELAB SERVICE CREDENTIALS
═══════════════════════════════════════════

🔧 ArgoCD GitOps
  URL:      https://argocd.$DOMAIN
  Username: admin
  Password: $argocd_password

📊 Grafana Monitoring
  URL:      https://grafana.$DOMAIN
  Username: admin
  Password: admin123
  (Change default password after first login)

📈 Prometheus Metrics
  URL:      https://prometheus.$DOMAIN
  Auth:     None required

🏠 Homepage Dashboard
  URL:      https://homepage.$DOMAIN
  Auth:     None required

📋 Traefik Dashboard
  URL:      http://$traefik_ip:8080/dashboard/
  API:      http://$traefik_ip:8080/api/
  Metrics:  http://$traefik_ip:8080/metrics
  Health:   http://$traefik_ip:8080/ping
  Auth:     None required

🌐 LoadBalancer Services
  Traefik IP: $traefik_ip
  HTTP Port:  80
  HTTPS Port: 443
  API Port:   8080

═══════════════════════════════════════════
Generated: $(date)
EOF
    
    log_success "$credentials_file created successfully"
}

display_summary() {
    echo ""
    echo -e "${CYAN}🎉 Applications Deployment Complete!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    
    # ArgoCD Applications status
    echo -e "${GREEN}ArgoCD Applications:${NC}"
    kubectl get applications -n argocd 2>/dev/null || echo "Failed to get applications"
    echo ""
    
    # Service URLs
    echo -e "${GREEN}Service URLs:${NC}"
    echo -e "  🏠 Homepage:    https://homepage.$DOMAIN"
    echo -e "  📊 Grafana:     https://grafana.$DOMAIN"
    echo -e "  📈 Prometheus:  https://prometheus.$DOMAIN"
    echo -e "  🔧 ArgoCD:      https://argocd.$DOMAIN"
    echo ""
    
    # LoadBalancer IP
    local traefik_ip=$(kubectl get svc traefik -n traefik-system -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null || echo "N/A")
    echo -e "${GREEN}LoadBalancer IP:${NC} $traefik_ip"
    echo -e "${GREEN}Traefik Dashboard:${NC} http://$traefik_ip:8080"
    echo ""
    
    # Credentials
    echo -e "${GREEN}Credentials:${NC} See service-credentials.txt"
    echo ""
    
    # GitOps info
    echo -e "${BLUE}🔄 GitOps Active:${NC} All changes to GitHub will auto-sync!"
    echo ""
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    log_module
    echo ""
    
    check_prerequisites
    deploy_applications
    wait_for_applications
    verify_services
    
    check_prerequisites
    deploy_applications
    wait_for_applications
    verify_services
    get_service_credentials
    display_summary
    
    log_success "Module $MODULE_NAME completed successfully!"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi