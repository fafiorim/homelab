#!/bin/bash

# =============================================================================
# Module 03: Traefik Ingress Controller
# =============================================================================
# This module handles:
# - Traefik installation and configuration
# - SSL certificate management with Let's Encrypt
# - Ingress class configuration
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
MODULE_NAME="Traefik"
MODULE_VERSION="1.0.0"
TRAEFIK_VERSION="v3.1"
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
    echo -e "${CYAN}🌐 Module: $MODULE_NAME v$MODULE_VERSION${NC}"
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
    
    # Check MetalLB
    if ! kubectl get pods -n metallb-system --no-headers 2>/dev/null | grep -q "Running"; then
        log_error "MetalLB is not running. Run MetalLB module first."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

check_existing_installation() {
    log_info "Checking for existing Traefik installation..."
    
    if kubectl get namespace traefik-system &> /dev/null; then
        log_warning "Traefik namespace already exists"
        if kubectl get pods -n traefik-system --no-headers 2>/dev/null | grep -q "Running"; then
            local running_pods=$(kubectl get pods -n traefik-system --no-headers | grep -c "Running" || echo "0")
            log_info "Found $running_pods running Traefik pods"
            
            # Check if LoadBalancer service exists
            if kubectl get svc traefik -n traefik-system &> /dev/null; then
                local lb_ip=$(kubectl get svc traefik -n traefik-system -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null || echo "")
                if [[ "$lb_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    log_success "Traefik already installed and has LoadBalancer IP: $lb_ip"
                    return 0
                fi
            fi
        fi
    fi
    
    return 1
}

create_namespace() {
    log_info "Creating Traefik namespace..."
    
    kubectl create namespace traefik-system --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Traefik namespace created"
}

create_secrets() {
    log_info "Creating Cloudflare API token secret..."
    
    # Create Cloudflare secret
    kubectl create secret generic cloudflare-api-token \
        --from-literal=CF_API_TOKEN="$CLOUDFLARE_API_TOKEN" \
        --namespace=traefik-system \
        --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Secrets created"
}

create_rbac() {
    log_info "Creating Traefik RBAC configuration..."
    
    cat > /tmp/traefik-rbac.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: traefik
  namespace: traefik-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: traefik
rules:
- apiGroups: [""]
  resources: ["services", "endpoints", "secrets", "nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions", "networking.k8s.io"]
  resources: ["ingresses", "ingressclasses"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions", "networking.k8s.io"]
  resources: ["ingresses/status"]
  verbs: ["update"]
- apiGroups: ["discovery.k8s.io"]
  resources: ["endpointslices"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: traefik
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik
subjects:
- kind: ServiceAccount
  name: traefik
  namespace: traefik-system
EOF
    
    kubectl apply -f /tmp/traefik-rbac.yaml
    rm -f /tmp/traefik-rbac.yaml
    
    log_success "RBAC configuration applied"
}

create_config() {
    log_info "Creating Traefik configuration..."
    
    cat > /tmp/traefik-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: traefik-config
  namespace: traefik-system
data:
  traefik.yml: |
    api:
      dashboard: true
      insecure: true

    ping: {}
    
    entryPoints:
      web:
        address: ":80"
        http:
          redirections:
            entryPoint:
              to: websecure
              scheme: https
      websecure:
        address: ":443"
      traefik:
        address: ":8080"
    
    providers:
      kubernetesIngress:
        ingressClass: traefik
    
    certificatesResolvers:
      letsencrypt:
        acme:
          email: admin@${DOMAIN}
          storage: /data/acme.json
          dnsChallenge:
            provider: cloudflare
            delayBeforeCheck: 30
            resolvers:
              - "1.1.1.1:53"
              - "8.8.8.8:53"
    
    log:
      level: INFO
    
    accessLog: {}
    
    global:
      checkNewVersion: false
      sendAnonymousUsage: false
EOF
    
    kubectl apply -f /tmp/traefik-config.yaml
    rm -f /tmp/traefik-config.yaml
    
    log_success "Configuration created"
}

create_ingress_class() {
    log_info "Creating Traefik IngressClass..."
    
    cat > /tmp/traefik-ingressclass.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: traefik
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: traefik.io/ingress-controller
EOF
    
    kubectl apply -f /tmp/traefik-ingressclass.yaml
    rm -f /tmp/traefik-ingressclass.yaml
    
    log_success "IngressClass created"
}

deploy_traefik() {
    log_info "Deploying Traefik..."
    
    cat > /tmp/traefik-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: traefik
  namespace: traefik-system
  labels:
    app: traefik
spec:
  replicas: 1
  selector:
    matchLabels:
      app: traefik
  template:
    metadata:
      labels:
        app: traefik
    spec:
      serviceAccountName: traefik
      containers:
        - name: traefik
          image: traefik:$TRAEFIK_VERSION
          args:
            - --configfile=/config/traefik.yml
          env:
            - name: CLOUDFLARE_DNS_API_TOKEN
              valueFrom:
                secretKeyRef:
                  name: cloudflare-api-token
                  key: CF_API_TOKEN
          ports:
            - name: web
              containerPort: 80
            - name: websecure
              containerPort: 443
            - name: admin
              containerPort: 8080
          volumeMounts:
            - name: config
              mountPath: /config
            - name: data
              mountPath: /data
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          readinessProbe:
            httpGet:
              path: /ping
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /ping
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 10
      volumes:
        - name: config
          configMap:
            name: traefik-config
        - name: data
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: traefik
  namespace: traefik-system
  labels:
    app: traefik
spec:
  type: LoadBalancer
  loadBalancerIP: $TRAEFIK_LOADBALANCER_IP
  ports:
    - port: 80
      targetPort: 80
      name: web
    - port: 443
      targetPort: 443
      name: websecure
    - port: 8080
      targetPort: 8080
      name: admin
  selector:
    app: traefik
EOF
    
    kubectl apply -f /tmp/traefik-deployment.yaml
    rm -f /tmp/traefik-deployment.yaml
    
    log_info "Waiting for Traefik to be ready..."
    kubectl wait --for=condition=ready pod -l app=traefik -n traefik-system --timeout=300s
    
    # Wait for LoadBalancer IP
    log_info "Waiting for LoadBalancer IP assignment..."
    local max_wait=120
    local waited=0
    while [ $waited -lt $max_wait ]; do
        local lb_ip=$(kubectl get svc traefik -n traefik-system -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null || echo "")
        if [[ "$lb_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        fi
        sleep 5
        waited=$((waited + 5))
    done
    
    log_success "Traefik deployed successfully"
}

verify_deployment() {
    log_info "Verifying Traefik deployment..."
    
    # Check pods
    local ready_pods=$(kubectl get pods -n traefik-system --no-headers | grep -c "Running" || echo "0")
    if [ "$ready_pods" -lt 1 ]; then
        log_error "Traefik pod is not running"
        kubectl get pods -n traefik-system
        return 1
    fi
    
    # Check LoadBalancer IP
    local lb_ip=$(kubectl get svc traefik -n traefik-system -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null || echo "")
    if [[ ! "$lb_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Traefik LoadBalancer IP not assigned"
        kubectl describe svc traefik -n traefik-system
        return 1
    fi
    
    # Test HTTP connectivity
    if curl -s -o /dev/null -w "%{http_code}" "http://$lb_ip:8080/ping" | grep -q "200"; then
        log_success "Traefik API is responding"
    else
        log_warning "Traefik API not responding on port 8080"
    fi
    
    log_success "Traefik verification completed"
    
    # Display deployment info
    echo ""
    echo -e "${CYAN}🎉 Traefik Deployment Complete!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${GREEN}Namespace:${NC} traefik-system"
    echo -e "${GREEN}LoadBalancer IP:${NC} $lb_ip"
    echo -e "${GREEN}Dashboard:${NC} http://$lb_ip:8080"
    echo ""
    echo -e "${GREEN}Services:${NC}"
    kubectl get svc -n traefik-system
    echo ""
    echo -e "${GREEN}Pods:${NC}"
    kubectl get pods -n traefik-system
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
        log_info "Traefik already installed, skipping installation"
        verify_deployment
    else
        create_namespace
        create_secrets
        create_rbac
        create_config
        create_ingress_class
        deploy_traefik
        verify_deployment
    fi
    
    log_success "Module $MODULE_NAME completed successfully!"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi