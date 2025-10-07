#!/bin/bash

# =============================================================================
# Homelab Modular Deployment Orchestrator
# =============================================================================
# This script orchestrates the deployment of a complete homelab infrastructure
# using modular components that can be run independently or as a complete suite.
#
# Modules:
# 1. Infrastructure - Proxmox VMs + Talos Kubernetes
# 2. MetalLB - LoadBalancer service
# 3. Traefik - Ingress controller with SSL
# 4. ArgoCD - GitOps controller
# 5. Applications - Application deployment via ArgoCD
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Script configuration
SCRIPT_NAME="Homelab Deployment Orchestrator"
SCRIPT_VERSION="2.0.0"
MODULES_DIR="modules"

# Enhanced configuration
MAX_RETRIES=3
RETRY_DELAY=30
SERVICE_WAIT_TIMEOUT=300
HEALTH_CHECK_INTERVAL=10

# Available modules in deployment order
MODULES=(
    "01-infrastructure"
    "02-metallb"
    "03-traefik"
    "04-argocd"
    "05-applications"
)

MODULE_DESCRIPTIONS=(
    "Infrastructure - Proxmox VMs + Talos Kubernetes"
    "MetalLB - LoadBalancer service"
    "Traefik - Ingress controller with SSL"
    "ArgoCD - GitOps controller"
    "Applications - Application deployment via ArgoCD"
)

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

log_header() {
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
    echo ""
}

log_step() {
    echo -e "${BLUE}🔹 $1${NC}"
}

log_progress() {
    local current=$1
    local total=$2
    local message=$3
    local percent=$((current * 100 / total))
    printf "\r${YELLOW}[%3d%%] $message${NC}" $percent
    if [ $current -eq $total ]; then
        echo ""
    fi
}

show_progress_bar() {
    local duration=$1
    local message="$2"
    local progress=0
    local total=20
    
    echo -n "$message "
    while [ $progress -le $total ]; do
        printf "█"
        sleep $((duration / total))
        ((progress++))
    done
    echo " ✅"
}

wait_for_condition() {
    local condition_cmd="$1"
    local message="$2"
    local timeout=${3:-300}
    local interval=${4:-10}
    
    local elapsed=0
    log_step "$message"
    
    while [ $elapsed -lt $timeout ]; do
        if eval "$condition_cmd" &>/dev/null; then
            log_success "Condition met after ${elapsed}s"
            return 0
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
        log_progress $elapsed $timeout "Waiting..."
    done
    
    log_error "Timeout after ${timeout}s waiting for: $message"
    return 1
}

retry_command() {
    local max_attempts=$1
    local delay=$2
    shift 2
    local cmd="$@"
    
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        log_step "Attempt $attempt/$max_attempts: $cmd"
        
        if eval "$cmd"; then
            log_success "Command succeeded on attempt $attempt"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_warning "Attempt $attempt failed, retrying in ${delay}s..."
            sleep $delay
        fi
        
        ((attempt++))
    done
    
    log_error "Command failed after $max_attempts attempts"
    return 1
}

show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "   ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    echo "   ┃                         🏠 HOMELAB DEPLOYMENT ORCHESTRATOR                    ┃"
    echo "   ┃                                   $SCRIPT_VERSION                                     ┃"
    echo "   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    echo -e "${NC}"
    echo ""
}

show_usage() {
    echo -e "${BOLD}Usage:${NC}"
    echo "  $0 [OPTIONS] [MODULE]"
    echo ""
    echo -e "${BOLD}OPTIONS:${NC}"
    echo "  -h, --help              Show this help message"
    echo "  -l, --list              List available modules"
    echo "  -f, --full              Deploy all modules in sequence (Enhanced v2.0)"
    echo "  -c, --check             Check prerequisites for all modules"
    echo "  -s, --status            Show deployment status (Enhanced)"
    echo "  -v, --verify            Verify all deployed services"
    echo "  --creds                 Show all service credentials"
    echo "  --test                  Run enhanced deployment test from scratch"
    echo "  --cleanup               Clean up all resources (DESTRUCTIVE)"
    echo ""
    echo -e "${BOLD}MODULES:${NC}"
    for i in "${!MODULES[@]}"; do
        echo "  ${MODULES[$i]}.sh    ${MODULE_DESCRIPTIONS[$i]}"
    done
    echo ""
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo "  $0 --test                        # Run enhanced deployment test from scratch"
    echo "  $0 --full                        # Deploy complete homelab (enhanced v2.0)"
    echo "  $0 01-infrastructure             # Deploy only infrastructure module"
    echo "  $0 --status                      # Show enhanced deployment status"
    echo "  $0 --verify                      # Verify all deployed services"
    echo "  $0 --creds                       # Show all service credentials"
    echo ""
}

list_modules() {
    log_header "Available Modules"
    
    for i in "${!MODULES[@]}"; do
        local module="${MODULES[$i]}"
        local description="${MODULE_DESCRIPTIONS[$i]}"
        local script_path="$MODULES_DIR/${module}.sh"
        
        if [ -f "$script_path" ]; then
            echo -e "${GREEN}✅ ${module}.sh${NC} - $description"
        else
            echo -e "${RED}❌ ${module}.sh${NC} - $description (FILE MISSING)"
        fi
    done
    echo ""
}

check_prerequisites() {
    log_header "Prerequisites Check"
    
    local missing_tools=()
    local required_tools=("curl" "jq" "kubectl" "talosctl" "helm")
    
    # Check required tools
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            echo -e "${GREEN}✅ $tool${NC} - $(command -v "$tool")"
        else
            echo -e "${RED}❌ $tool${NC} - Not found"
            missing_tools+=("$tool")
        fi
    done
    
    # Check configuration files
    local config_files=("config.conf" "cluster.conf")
    for config_file in "${config_files[@]}"; do
        if [ -f "$config_file" ]; then
            echo -e "${GREEN}✅ $config_file${NC} - Found"
        else
            echo -e "${RED}❌ $config_file${NC} - Not found"
        fi
    done
    
    # Check modules directory
    if [ -d "$MODULES_DIR" ]; then
        echo -e "${GREEN}✅ modules directory${NC} - Found"
        
        # Check individual module scripts
        local missing_modules=()
        for module in "${MODULES[@]}"; do
            if [ -f "$MODULES_DIR/${module}.sh" ]; then
                echo -e "${GREEN}✅ ${module}.sh${NC} - Found"
            else
                echo -e "${RED}❌ ${module}.sh${NC} - Missing"
                missing_modules+=("$module")
            fi
        done
        
        if [ ${#missing_modules[@]} -gt 0 ]; then
            log_error "Missing module scripts: ${missing_modules[*]}"
            return 1
        fi
    else
        echo -e "${RED}❌ modules directory${NC} - Not found"
        return 1
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    
    log_success "All prerequisites satisfied!"
    return 0
}

run_module() {
    local module_name="$1"
    local retry_enabled=${2:-true}
    local script_path="$MODULES_DIR/${module_name}.sh"
    
    if [ ! -f "$script_path" ]; then
        log_error "Module script not found: $script_path"
        return 1
    fi
    
    log_header "Executing Module: $module_name"
    
    # Make script executable
    chmod +x "$script_path"
    
    # Record start time
    local start_time=$(date +%s)
    local start_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_step "Start time: $start_timestamp"
    
    # Execute module with retry logic if enabled
    local success=false
    local attempts=1
    
    if [ "$retry_enabled" = "true" ] && [[ "$module_name" =~ ^(02-metallb|03-traefik|04-argocd)$ ]]; then
        # Network-dependent modules get retry logic
        while [ $attempts -le $MAX_RETRIES ] && [ "$success" = "false" ]; do
            log_step "Module execution attempt $attempts/$MAX_RETRIES"
            
            if bash "$script_path"; then
                success=true
                break
            else
                if [ $attempts -lt $MAX_RETRIES ]; then
                    log_warning "Module $module_name failed on attempt $attempts, retrying in ${RETRY_DELAY}s..."
                    sleep $RETRY_DELAY
                fi
                ((attempts++))
            fi
        done
    else
        # Infrastructure and applications run once
        if bash "$script_path"; then
            success=true
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local end_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ "$success" = "true" ]; then
        log_success "Module $module_name completed successfully!"
        log_step "Duration: ${duration}s (${start_timestamp} → ${end_timestamp})"
        
        # Post-module health check for critical services
        if [[ "$module_name" =~ ^(01-infrastructure|02-metallb|03-traefik|04-argocd)$ ]]; then
            perform_module_health_check "$module_name"
        fi
        
        return 0
    else
        log_error "Module $module_name failed after $attempts attempts and ${duration}s"
        return 1
    fi
}

perform_module_health_check() {
    local module_name="$1"
    
    log_step "Performing post-deployment health check for $module_name"
    
    case "$module_name" in
        "01-infrastructure")
            wait_for_condition "kubectl get nodes --no-headers | grep -c Ready | grep -q 3" "All 3 nodes to be Ready" 180 15
            ;;
        "02-metallb")
            wait_for_condition "kubectl get pods -n metallb-system --no-headers | grep -c Running | grep -q 4" "MetalLB pods to be Running" 120 10
            ;;
        "03-traefik")
            wait_for_condition "kubectl get svc traefik -n traefik-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'" "Traefik LoadBalancer IP assignment" 180 15
            ;;
        "04-argocd")
            wait_for_condition "kubectl get pods -n argocd --no-headers | grep -c Running | grep -q 7" "ArgoCD pods to be Running" 180 15
            ;;
    esac
}

deploy_full() {
    log_header "Enhanced Full Homelab Deployment v2.0"
    
    local failed_modules=()
    local successful_modules=()
    local module_timings=()
    local start_time=$(date +%s)
    local start_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_info "Starting enhanced full deployment of ${#MODULES[@]} modules..."
    log_step "Deployment started at: $start_timestamp"
    echo ""
    
    # Create deployment log file
    local log_file="deployment-$(date +%Y%m%d-%H%M%S).log"
    echo "🚀 Enhanced Homelab Deployment Log - $start_timestamp" > "$log_file"
    echo "================================================================" >> "$log_file"
    echo "" >> "$log_file"
    
    for i in "${!MODULES[@]}"; do
        local module="${MODULES[$i]}"
        local description="${MODULE_DESCRIPTIONS[$i]}"
        local module_start=$(date +%s)
        local module_start_time=$(date '+%H:%M:%S')
        
        echo -e "${CYAN}📦 Module $((i+1))/${#MODULES[@]}: $description${NC}"
        echo "Module $((i+1))/${#MODULES[@]}: $description - Start: $module_start_time" >> "$log_file"
        
        log_progress $((i+1)) ${#MODULES[@]} "Deploying $module"
        
        if run_module "$module" true; then
            local module_end=$(date +%s)
            local module_duration=$((module_end - module_start))
            local module_end_time=$(date '+%H:%M:%S')
            
            echo -e "${GREEN}✅ Module $module completed successfully in ${module_duration}s${NC}"
            successful_modules+=("$module")
            module_timings+=("$module:${module_duration}s")
            echo "  ✅ SUCCESS - Duration: ${module_duration}s (${module_start_time} → ${module_end_time})" >> "$log_file"
        else
            local module_end=$(date +%s)
            local module_duration=$((module_end - module_start))
            local module_end_time=$(date '+%H:%M:%S')
            
            echo -e "${RED}❌ Module $module failed after ${module_duration}s${NC}"
            failed_modules+=("$module")
            module_timings+=("$module:FAILED(${module_duration}s)")
            echo "  ❌ FAILED - Duration: ${module_duration}s (${module_start_time} → ${module_end_time})" >> "$log_file"
            
            # Enhanced error handling with retry option
            echo ""
            echo -e "${YELLOW}Module $module failed. Options:${NC}"
            echo "  (r) Retry this module"
            echo "  (c) Continue with remaining modules"
            echo "  (a) Abort deployment"
            
            while true; do
                read -p "Choose option (r/c/a): " -n 1 -r
                echo ""
                case $REPLY in
                    [Rr])
                        log_info "Retrying module $module..."
                        if run_module "$module" false; then
                            # Remove from failed and add to successful
                            failed_modules=("${failed_modules[@]/$module}")
                            successful_modules+=("$module")
                            echo -e "${GREEN}✅ Module $module retry successful!${NC}"
                            echo "  ✅ RETRY SUCCESS" >> "$log_file"
                        else
                            echo -e "${RED}❌ Module $module retry also failed${NC}"
                            echo "  ❌ RETRY FAILED" >> "$log_file"
                        fi
                        break
                        ;;
                    [Cc])
                        log_info "Continuing with remaining modules..."
                        break
                        ;;
                    [Aa])
                        log_error "Deployment aborted by user"
                        echo "  🛑 ABORTED BY USER" >> "$log_file"
                        return 1
                        ;;
                    *)
                        echo "Invalid option. Please choose r, c, or a."
                        ;;
                esac
            done
        fi
        echo ""
    done
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    local minutes=$((total_duration / 60))
    local seconds=$((total_duration % 60))
    local end_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Enhanced deployment summary
    log_header "Enhanced Deployment Summary"
    
    echo "" >> "$log_file"
    echo "DEPLOYMENT SUMMARY" >> "$log_file"
    echo "==================" >> "$log_file"
    
    if [ ${#failed_modules[@]} -eq 0 ]; then
        echo -e "${GREEN}🎉 FULL DEPLOYMENT SUCCESSFUL!${NC}"
        echo -e "${GREEN}All ${#MODULES[@]} modules deployed successfully${NC}"
        echo "Status: ✅ COMPLETE SUCCESS" >> "$log_file"
    else
        # Filter out empty elements from failed_modules array
        local filtered_failed=()
        for module in "${failed_modules[@]}"; do
            [ -n "$module" ] && filtered_failed+=("$module")
        done
        failed_modules=("${filtered_failed[@]}")
        
        echo -e "${YELLOW}⚠️  PARTIAL DEPLOYMENT${NC}"
        echo -e "${GREEN}Successful modules: ${#successful_modules[@]}/${#MODULES[@]}${NC}"
        echo -e "${RED}Failed modules: ${#failed_modules[@]} (${failed_modules[*]})${NC}"
        echo "Status: ⚠️ PARTIAL SUCCESS" >> "$log_file"
        echo "Failed: ${failed_modules[*]}" >> "$log_file"
    fi
    
    echo -e "${BLUE}Total deployment time: ${minutes}m ${seconds}s${NC}"
    echo -e "${BLUE}Started: $start_timestamp${NC}"
    echo -e "${BLUE}Completed: $end_timestamp${NC}"
    
    echo "" >> "$log_file"
    echo "Timing Details:" >> "$log_file"
    for timing in "${module_timings[@]}"; do
        echo "  $timing" >> "$log_file"
    done
    echo "Total: ${minutes}m ${seconds}s ($start_timestamp → $end_timestamp)" >> "$log_file"
    
    log_success "Detailed deployment log saved to: $log_file"
    echo ""
    
    # Enhanced final status check
    log_step "Performing comprehensive post-deployment verification..."
    show_status
    
    # Additional verification if all modules succeeded
    if [ ${#failed_modules[@]} -eq 0 ]; then
        echo ""
        log_step "Running enhanced service verification..."
        verify_services
    fi
}

show_status() {
    log_header "Enhanced Deployment Status"
    
    # Check if kubeconfig exists
    if [ ! -f "kubeconfig" ]; then
        echo -e "${RED}❌ No kubeconfig found - Infrastructure not deployed${NC}"
        return 1
    fi
    
    export KUBECONFIG="./kubeconfig"
    
    # Check cluster connectivity with retry
    log_step "Checking cluster connectivity..."
    if ! retry_command 3 10 "kubectl get nodes --no-headers >/dev/null"; then
        echo -e "${RED}❌ Cannot connect to Kubernetes cluster after retries${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🔗 Cluster Connection: OK${NC}"
    
    # Enhanced node status check
    log_step "Checking node status..."
    local node_info=$(kubectl get nodes --no-headers 2>/dev/null)
    local node_count=$(echo "$node_info" | wc -l | tr -d ' ')
    local ready_count=$(echo "$node_info" | grep -c "Ready" || echo "0")
    local not_ready_count=$((node_count - ready_count))
    
    if [ $ready_count -eq $node_count ] && [ $node_count -gt 0 ]; then
        echo -e "${GREEN}📊 Cluster Nodes: $ready_count/$node_count Ready ✅${NC}"
    else
        echo -e "${YELLOW}📊 Cluster Nodes: $ready_count/$node_count Ready ($not_ready_count pending) ⚠️${NC}"
    fi
    
    # Enhanced component status check
    log_step "Checking component health..."
    local components=("metallb-system:MetalLB" "traefik-system:Traefik" "argocd:ArgoCD")
    local all_healthy=true
    
    for component in "${components[@]}"; do
        local namespace=$(echo "$component" | cut -d: -f1)
        local name=$(echo "$component" | cut -d: -f2)
        
        if kubectl get namespace "$namespace" &> /dev/null; then
            local pod_info=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null)
            local pod_count=$(echo "$pod_info" | wc -l | tr -d ' ')
            local running_pods=$(echo "$pod_info" | grep -c "Running" || echo "0")
            local pending_pods=$(echo "$pod_info" | grep -c "Pending\|ContainerCreating" || echo "0")
            
            if [ $running_pods -eq $pod_count ] && [ $pod_count -gt 0 ]; then
                echo -e "${GREEN}✅ $name: $running_pods/$pod_count Running 🟢${NC}"
            elif [ $pending_pods -gt 0 ]; then
                echo -e "${YELLOW}⏳ $name: $running_pods/$pod_count Running ($pending_pods pending) 🟡${NC}"
                all_healthy=false
            else
                echo -e "${RED}❌ $name: $running_pods/$pod_count Running 🔴${NC}"
                all_healthy=false
            fi
        else
            echo -e "${RED}❌ $name: Not deployed ⚫${NC}"
            all_healthy=false
        fi
    done
    
    # Enhanced ArgoCD applications check
    if kubectl get namespace argocd &> /dev/null; then
        log_step "Checking ArgoCD applications..."
        local app_info=$(kubectl get applications -n argocd --no-headers 2>/dev/null || echo "")
        local app_count=$(echo "$app_info" | wc -l | tr -d ' ')
        
        if [ "$app_count" -gt 0 ] && [ -n "$app_info" ]; then
            local synced_count=$(kubectl get applications -n argocd -o json 2>/dev/null | jq -r '.items[] | select(.status.sync.status=="Synced") | .metadata.name' | wc -l | tr -d ' ' || echo "0")
            local healthy_count=$(kubectl get applications -n argocd -o json 2>/dev/null | jq -r '.items[] | select(.status.health.status=="Healthy") | .metadata.name' | wc -l | tr -d ' ' || echo "0")
            
            if [ $synced_count -eq $app_count ] && [ $healthy_count -eq $app_count ]; then
                echo -e "${GREEN}📦 ArgoCD Apps: $synced_count/$app_count Synced, $healthy_count/$app_count Healthy ✅${NC}"
            else
                echo -e "${YELLOW}📦 ArgoCD Apps: $synced_count/$app_count Synced, $healthy_count/$app_count Healthy ⚠️${NC}"
            fi
        else
            echo -e "${YELLOW}📦 ArgoCD Apps: No applications found${NC}"
        fi
    fi
    
    # Enhanced LoadBalancer and service check
    log_step "Checking LoadBalancer and services..."
    if kubectl get svc traefik -n traefik-system &> /dev/null; then
        local lb_ip=$(kubectl get svc traefik -n traefik-system -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null || echo "")
        if [[ "$lb_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo -e "${GREEN}🌐 LoadBalancer IP: $lb_ip ✅${NC}"
            
            # Load config to get domain
            if [ -f "config.conf" ]; then
                source config.conf
                echo -e "${GREEN}🔗 Service URLs & Credentials:${NC}"
                echo -e "   🏠 Homepage:    https://homepage.$DOMAIN"
                echo -e "   📊 Grafana:     https://grafana.$DOMAIN"
                
                # Get Grafana credentials if available
                local grafana_user=""
                local grafana_pass=""
                if kubectl get secret -n monitoring grafana-admin-credentials &>/dev/null; then
                    grafana_user=$(kubectl get secret grafana-admin-credentials -n monitoring -o jsonpath="{.data.admin-user}" 2>/dev/null | base64 -d 2>/dev/null || echo "admin")
                    grafana_pass=$(kubectl get secret grafana-admin-credentials -n monitoring -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
                elif kubectl get secret -n monitoring grafana &>/dev/null; then
                    grafana_user="admin"
                    grafana_pass=$(kubectl get secret grafana -n monitoring -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
                fi
                
                if [ -n "$grafana_pass" ]; then
                    echo -e "      ${BLUE}├─ User: $grafana_user${NC}"
                    echo -e "      ${BLUE}└─ Pass: $grafana_pass${NC}"
                fi
                
                echo -e "   📈 Prometheus:  https://prometheus.$DOMAIN"
                echo -e "   🔧 ArgoCD:      https://argocd.$DOMAIN"
                
                # Get ArgoCD credentials
                local argocd_user="admin"
                local argocd_pass=""
                if kubectl get secret -n argocd argocd-initial-admin-secret &>/dev/null; then
                    argocd_pass=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
                elif [ -f ".argocd-admin-password" ]; then
                    argocd_pass=$(cat .argocd-admin-password 2>/dev/null || echo "")
                fi
                
                if [ -n "$argocd_pass" ]; then
                    echo -e "      ${BLUE}├─ User: $argocd_user${NC}"
                    echo -e "      ${BLUE}└─ Pass: $argocd_pass${NC}"
                fi
                
                echo -e "   📋 Dashboard:   http://$lb_ip:8080/dashboard/"
                echo -e "      ${BLUE}└─ Traefik Web UI (no auth required)${NC}"
                
                # Additional service credentials from service-credentials.txt if available
                if [ -f "service-credentials.txt" ]; then
                    echo ""
                    echo -e "${GREEN}📋 Additional Credentials:${NC}"
                    echo -e "   ${BLUE}└─ Saved to: service-credentials.txt${NC}"
                fi
            fi
        else
            echo -e "${YELLOW}⏳ LoadBalancer IP: Pending assignment ⚠️${NC}"
            all_healthy=false
        fi
    else
        echo -e "${RED}❌ LoadBalancer: Traefik service not found${NC}"
        all_healthy=false
    fi
    
    # Overall health summary
    echo ""
    if [ "$all_healthy" = "true" ]; then
        echo -e "${GREEN}🎆 Overall Status: ALL SYSTEMS HEALTHY 🟢${NC}"
    else
        echo -e "${YELLOW}⚠️ Overall Status: SOME ISSUES DETECTED 🟡${NC}"
    fi
    
    echo ""
}

verify_services() {
    log_header "Service Verification"
    
    # Check if config exists
    if [ ! -f "config.conf" ]; then
        log_error "config.conf not found"
        return 1
    fi
    
    source config.conf
    
    local services=("homepage" "grafana" "prometheus" "argocd")
    local working_services=()
    local failed_services=()
    
    for service in "${services[@]}"; do
        local url="https://$service.$DOMAIN"
        echo -n "Testing $service... "
        
        local http_code=$(curl -k -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
        
        if [[ "$http_code" =~ ^[23] ]]; then
            echo -e "${GREEN}✅ $http_code${NC}"
            working_services+=("$service")
        else
            echo -e "${RED}❌ $http_code${NC}"
            failed_services+=("$service")
        fi
    done
    
    echo ""
    if [ ${#failed_services[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Some services are not accessible: ${failed_services[*]}${NC}"
        echo -e "${BLUE}This may be normal during initial deployment or DNS propagation${NC}"
    else
        echo -e "${GREEN}🎉 All services are accessible!${NC}"
    fi
    
    # Show available credentials for accessible services
    echo ""
    echo -e "${GREEN}🔑 Service Credentials:${NC}"
    
    # ArgoCD credentials
    if [[ " ${working_services[*]} " =~ " argocd " ]]; then
        local argocd_user="admin"
        local argocd_pass=""
        if kubectl get secret -n argocd argocd-initial-admin-secret &>/dev/null; then
            argocd_pass=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
        elif [ -f ".argocd-admin-password" ]; then
            argocd_pass=$(cat .argocd-admin-password 2>/dev/null || echo "")
        fi
        
        if [ -n "$argocd_pass" ]; then
            echo -e "   🔧 ArgoCD: $argocd_user / $argocd_pass"
        fi
    fi
    
    # Grafana credentials
    if [[ " ${working_services[*]} " =~ " grafana " ]]; then
        local grafana_user=""
        local grafana_pass=""
        if kubectl get secret -n monitoring grafana-admin-credentials &>/dev/null; then
            grafana_user=$(kubectl get secret grafana-admin-credentials -n monitoring -o jsonpath="{.data.admin-user}" 2>/dev/null | base64 -d 2>/dev/null || echo "admin")
            grafana_pass=$(kubectl get secret grafana-admin-credentials -n monitoring -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
        elif kubectl get secret -n monitoring grafana &>/dev/null; then
            grafana_user="admin"
            grafana_pass=$(kubectl get secret grafana -n monitoring -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
        fi
        
        if [ -n "$grafana_pass" ]; then
            echo -e "   📊 Grafana: $grafana_user / $grafana_pass"
        fi
    fi
    
    # Homepage (usually no credentials required)
    if [[ " ${working_services[*]} " =~ " homepage " ]]; then
        echo -e "   🏠 Homepage: No authentication required"
    fi
    
    # Prometheus (usually no credentials by default)
    if [[ " ${working_services[*]} " =~ " prometheus " ]]; then
        echo -e "   📈 Prometheus: No authentication required"
    fi
    
    # Additional credentials file
    if [ -f "service-credentials.txt" ]; then
        echo -e "   📋 Complete credentials saved to: ${BLUE}service-credentials.txt${NC}"
    fi
    
    echo ""
}

show_credentials() {
    log_header "Service Credentials Summary"
    
    # Check if kubeconfig exists
    if [ ! -f "kubeconfig" ]; then
        echo -e "${RED}❌ No kubeconfig found - Infrastructure not deployed${NC}"
        return 1
    fi
    
    export KUBECONFIG="./kubeconfig"
    
    # Check if config exists
    if [ ! -f "config.conf" ]; then
        log_error "config.conf not found"
        return 1
    fi
    
    source config.conf
    
    echo -e "${GREEN}🔑 Complete Service Credentials:${NC}"
    echo ""
    
    # ArgoCD credentials
    local argocd_user="admin"
    local argocd_pass=""
    if kubectl get secret -n argocd argocd-initial-admin-secret &>/dev/null; then
        argocd_pass=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
    elif [ -f ".argocd-admin-password" ]; then
        argocd_pass=$(cat .argocd-admin-password 2>/dev/null || echo "")
    fi
    
    if [ -n "$argocd_pass" ]; then
        echo -e "🔧 ${BOLD}ArgoCD GitOps Platform:${NC}"
        echo -e "   URL:      https://argocd.$DOMAIN"
        echo -e "   Username: ${GREEN}$argocd_user${NC}"
        echo -e "   Password: ${GREEN}$argocd_pass${NC}"
        echo ""
    fi
    
    # Grafana credentials
    local grafana_user=""
    local grafana_pass=""
    if kubectl get secret -n monitoring grafana-admin-credentials &>/dev/null; then
        grafana_user=$(kubectl get secret grafana-admin-credentials -n monitoring -o jsonpath="{.data.admin-user}" 2>/dev/null | base64 -d 2>/dev/null || echo "admin")
        grafana_pass=$(kubectl get secret grafana-admin-credentials -n monitoring -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
    elif kubectl get secret -n monitoring grafana &>/dev/null; then
        grafana_user="admin"
        grafana_pass=$(kubectl get secret grafana -n monitoring -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
    fi
    
    if [ -n "$grafana_pass" ]; then
        echo -e "📊 ${BOLD}Grafana Monitoring:${NC}"
        echo -e "   URL:      https://grafana.$DOMAIN"
        echo -e "   Username: ${GREEN}$grafana_user${NC}"
        echo -e "   Password: ${GREEN}$grafana_pass${NC}"
        echo ""
    fi
    
    # Services without authentication
    echo -e "🌐 ${BOLD}Services (No Authentication):${NC}"
    echo -e "   🏠 Homepage:    https://homepage.$DOMAIN"
    echo -e "   📈 Prometheus:  https://prometheus.$DOMAIN"
    
    # Get LoadBalancer IP for Traefik dashboard
    local lb_ip=$(kubectl get svc traefik -n traefik-system -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null || echo "")
    if [[ "$lb_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "   📋 Dashboard:   http://$lb_ip:8080/dashboard/"
    fi
    echo ""
    
    # Additional information
    echo -e "${BLUE}📋 Additional Information:${NC}"
    echo -e "   • LoadBalancer IP: $lb_ip"
    echo -e "   • Kubernetes API: Available via kubeconfig"
    echo -e "   • Talos API: Available via talos-configs/"
    
    if [ -f "service-credentials.txt" ]; then
        echo -e "   • Complete credentials file: ${GREEN}service-credentials.txt${NC}"
    fi
    
    echo ""
}

cleanup_deployment() {
    log_warning "This will destroy ALL deployed resources!"
    echo ""
    echo "This includes:"
    echo "  - All Proxmox VMs"
    echo "  - All Kubernetes resources"
    echo "  - All configuration files"
    echo ""
    read -p "Are you sure you want to proceed? Type 'DELETE' to confirm: " confirm
    
    if [ "$confirm" != "DELETE" ]; then
        log_info "Cleanup cancelled"
        return 0
    fi
    
    log_header "Cleanup Deployment"
    
    # Run cleanup script if it exists
    if [ -f "cleanup_vms.sh" ]; then
        log_info "Running VM cleanup script..."
        echo "y" | ./cleanup_vms.sh
    fi
    
    # Remove local files
    log_info "Removing local files..."
    rm -rf talos-configs kubeconfig talos-secrets.yaml .argocd-admin-password service-credentials.txt
    
    log_success "Cleanup completed"
}

run_enhanced_test() {
    log_header "Enhanced Deployment Test from Scratch"
    
    local test_start=$(date +%s)
    local test_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_info "Starting comprehensive deployment test..."
    log_step "Test initiated at: $test_timestamp"
    echo ""
    
    # Step 1: Cleanup any existing deployment
    log_step "Phase 1: Complete cleanup to ensure clean slate"
    echo "DELETE" | cleanup_deployment
    
    if [ $? -ne 0 ]; then
        log_error "Cleanup phase failed"
        return 1
    fi
    
    # Small delay to ensure cleanup is complete
    log_step "Waiting for cleanup to complete..."
    sleep 10
    
    # Step 2: Prerequisites verification
    log_step "Phase 2: Enhanced prerequisites verification"
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        return 1
    fi
    
    # Step 3: Full deployment with enhanced features
    log_step "Phase 3: Enhanced full deployment"
    if deploy_full; then
        local test_end=$(date +%s)
        local test_duration=$((test_end - test_start))
        local test_minutes=$((test_duration / 60))
        local test_seconds=$((test_duration % 60))
        
        log_header "🎉 Enhanced Deployment Test Results"
        echo -e "${GREEN}✅ COMPREHENSIVE TEST SUCCESSFUL!${NC}"
        echo -e "${GREEN}Total test duration: ${test_minutes}m ${test_seconds}s${NC}"
        echo -e "${GREEN}Started: $test_timestamp${NC}"
        echo -e "${GREEN}Completed: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
        echo ""
        
        # Final comprehensive verification
        log_step "Running final comprehensive verification..."
        show_status
        echo ""
        verify_services
        
        return 0
    else
        log_error "Enhanced deployment test failed"
        return 1
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    show_banner
    
    # Parse command line arguments
    case "${1:-}" in
        -h|--help)
            show_usage
            ;;
        -l|--list)
            list_modules
            ;;
        -c|--check)
            if check_prerequisites; then
                exit 0
            else
                exit 1
            fi
            ;;
        -f|--full)
            if ! check_prerequisites; then
                log_error "Prerequisites check failed"
                exit 1
            fi
            deploy_full
            ;;
        -s|--status)
            show_status
            ;;
        -v|--verify)
            verify_services
            ;;
        --cleanup)
            cleanup_deployment
            ;;
        --creds)
            show_credentials
            ;;
        --test)
            if ! check_prerequisites; then
                log_error "Prerequisites check failed"
                exit 1
            fi
            run_enhanced_test
            ;;
        01-infrastructure|02-metallb|03-traefik|04-argocd|05-applications)
            if ! check_prerequisites; then
                log_error "Prerequisites check failed"
                exit 1
            fi
            run_module "$1"
            ;;
        "")
            show_usage
            ;;
        *)
            log_error "Unknown option or module: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi