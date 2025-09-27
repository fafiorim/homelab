#!/bin/bash

# Homepage Kubernetes Deployment Script
# This script deploys Homepage with proper configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="default"
DEPLOYMENT_NAME="homepage"
SERVICE_TYPE="nodeport"  # Options: nodeport, loadbalancer, clusterip

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl could not be found. Please install kubectl first."
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    log_info "Kubernetes cluster connection verified"
}

get_node_ip() {
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    if [ -z "$NODE_IP" ]; then
        log_error "Could not determine node IP address"
        exit 1
    fi
    echo "$NODE_IP"
}

deploy_homepage() {
    log_info "Deploying Homepage to Kubernetes..."
    
    # Apply main manifest
    kubectl apply -f manifests/homepage-complete.yaml
    
    # Apply additional services based on type
    case $SERVICE_TYPE in
        "loadbalancer")
            log_info "Deploying LoadBalancer service..."
            kubectl apply -f manifests/service-loadbalancer.yaml
            ;;
        "nodeport")
            log_info "NodePort service already included in main manifest"
            ;;
        "clusterip")
            log_info "ClusterIP service already included in main manifest"
            ;;
        *)
            log_warn "Unknown service type: $SERVICE_TYPE. Using default NodePort."
            ;;
    esac
    
    log_info "Waiting for deployment to be ready..."
    kubectl rollout status deployment/$DEPLOYMENT_NAME -n $NAMESPACE --timeout=300s
}

configure_allowed_hosts() {
    local node_ip=$(get_node_ip)
    local allowed_hosts="localhost:3000,$node_ip:30090"
    
    # Add LoadBalancer IP if service type is loadbalancer
    if [ "$SERVICE_TYPE" = "loadbalancer" ]; then
        log_info "Waiting for LoadBalancer external IP..."
        local external_ip=""
        local attempts=0
        
        while [ -z "$external_ip" ] && [ $attempts -lt 30 ]; do
            external_ip=$(kubectl get svc homepage-lb -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
            if [ -z "$external_ip" ]; then
                sleep 10
                ((attempts++))
            fi
        done
        
        if [ -n "$external_ip" ]; then
            allowed_hosts="$allowed_hosts,$external_ip"
            log_info "LoadBalancer external IP: $external_ip"
        else
            log_warn "LoadBalancer external IP not available after 5 minutes"
        fi
    fi
    
    log_info "Configuring HOMEPAGE_ALLOWED_HOSTS: $allowed_hosts"
    kubectl set env deployment/$DEPLOYMENT_NAME HOMEPAGE_ALLOWED_HOSTS="$allowed_hosts" -n $NAMESPACE
    
    # Wait for rollout to complete
    kubectl rollout status deployment/$DEPLOYMENT_NAME -n $NAMESPACE --timeout=120s
}

show_access_info() {
    local node_ip=$(get_node_ip)
    
    log_info "Homepage deployment completed successfully!"
    echo ""
    echo "Access Information:"
    echo "=================="
    
    # NodePort access
    echo "NodePort: http://$node_ip:30090"
    
    # Port-forward access
    echo "Port-forward: kubectl port-forward svc/homepage 3000:3000"
    echo "              Then access: http://localhost:3000"
    
    # LoadBalancer access (if applicable)
    if [ "$SERVICE_TYPE" = "loadbalancer" ]; then
        local external_ip=$(kubectl get svc homepage-lb -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -n "$external_ip" ]; then
            echo "LoadBalancer: http://$external_ip"
        fi
    fi
    
    echo ""
    echo "Management Commands:"
    echo "==================="
    echo "Check status: kubectl get pods -l app.kubernetes.io/name=homepage"
    echo "View logs: kubectl logs -l app.kubernetes.io/name=homepage"
    echo "Edit config: kubectl edit configmap homepage"
    echo "Restart: kubectl rollout restart deployment/homepage"
    echo ""
}

show_help() {
    echo "Homepage Kubernetes Deployment Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -n, --namespace NAME    Deploy to specific namespace (default: default)"
    echo "  -s, --service TYPE      Service type: nodeport, loadbalancer, clusterip (default: nodeport)"
    echo "  --check-only            Only check prerequisites, don't deploy"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Deploy with default settings"
    echo "  $0 -s loadbalancer                   # Deploy with LoadBalancer service"
    echo "  $0 -n homepage-system               # Deploy to custom namespace"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -s|--service)
            SERVICE_TYPE="$2"
            shift 2
            ;;
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log_info "Starting Homepage deployment..."
    log_info "Namespace: $NAMESPACE"
    log_info "Service Type: $SERVICE_TYPE"
    
    check_kubectl
    
    if [ "$CHECK_ONLY" = true ]; then
        log_info "Prerequisites check completed successfully"
        exit 0
    fi
    
    deploy_homepage
    configure_allowed_hosts
    show_access_info
}

# Run main function
main "$@"