#!/bin/bash

# ArgoCD Installation Script using Official Helm Chart
# This script installs ArgoCD on the Talos Kubernetes cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Installing ArgoCD on Talos Kubernetes Cluster${NC}"
echo ""

# Check if kubeconfig exists
if [ ! -f "kubeconfig" ]; then
    echo -e "${RED}✗ kubeconfig not found${NC}"
    echo -e "${YELLOW}Please run './talos-cluster.sh deploy' first${NC}"
    exit 1
fi

# Set kubeconfig
export KUBECONFIG=./kubeconfig

# Check if cluster is accessible
echo -e "${YELLOW}🔍 Checking cluster connectivity...${NC}"
if ! kubectl get nodes >/dev/null 2>&1; then
    echo -e "${RED}✗ Cannot connect to cluster${NC}"
    echo -e "${YELLOW}Please ensure the cluster is running and accessible${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Cluster is accessible${NC}"

# Check if Helm is installed
echo -e "${YELLOW}🔍 Checking Helm installation...${NC}"
if ! command -v helm &> /dev/null; then
    echo -e "${RED}✗ Helm is not installed${NC}"
    echo -e "${YELLOW}Installing Helm...${NC}"
    
    # Install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}✗ Failed to install Helm${NC}"
        echo -e "${YELLOW}Please install Helm manually: https://helm.sh/docs/intro/install/${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Helm is available${NC}"

# Add ArgoCD Helm repository
echo -e "${YELLOW}📦 Adding ArgoCD Helm repository...${NC}"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Create ArgoCD namespace
echo -e "${YELLOW}📁 Creating ArgoCD namespace...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD with custom values
echo -e "${YELLOW}🚀 Installing ArgoCD...${NC}"
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --values manifests/argocd/values.yaml \
  --wait

# Wait for ArgoCD to be ready
echo -e "${YELLOW}⏳ Waiting for ArgoCD to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo -e "${GREEN}✅ ArgoCD installed successfully!${NC}"
echo ""

# Get ArgoCD admin password
echo -e "${YELLOW}🔑 Getting ArgoCD admin password...${NC}"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Password not available yet")

if [ -n "$ARGOCD_PASSWORD" ] && [ "$ARGOCD_PASSWORD" != "Password not available yet" ]; then
    echo -e "${GREEN}✓ ArgoCD admin password: ${ARGOCD_PASSWORD}${NC}"
else
    echo -e "${YELLOW}⚠ ArgoCD admin password not available yet. Check with:${NC}"
    echo -e "${BLUE}  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d${NC}"
fi

echo ""
echo -e "${GREEN}🎉 ArgoCD installation complete!${NC}"
echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}                    ARGOCD ACCESS INFORMATION                    ${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}🌐 ArgoCD Web UI:${NC}"
echo -e "   ${BLUE}URL:${NC} http://10.10.21.110:30080"
echo ""
echo -e "${GREEN}🔐 Login Credentials:${NC}"
echo -e "   ${BLUE}Username:${NC} admin"
echo -e "   ${BLUE}Password:${NC} ${ARGOCD_PASSWORD:-<check with kubectl command above>}"
echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo -e "  1. Open your browser and go to: http://10.10.21.110:30080"
echo -e "  2. Login with the credentials above"
echo -e "  3. Connect your GitHub repository"
echo -e "  4. Deploy applications via GitOps"
echo ""
echo -e "${BLUE}💡 Tip: You can also use the ArgoCD CLI:${NC}"
echo -e "  argocd login 10.10.21.110:30080"
echo -e "  argocd account update-password"