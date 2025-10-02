#!/bin/bash

# Deploy Applications via ArgoCD
# This script deploys applications to ArgoCD for GitOps management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Deploying Applications via ArgoCD${NC}"
echo ""

# Load configuration
if [ ! -f "cluster.conf" ]; then
    echo -e "${RED}✗ cluster.conf not found${NC}"
    echo -e "${YELLOW}Please copy cluster.conf.example to cluster.conf and configure it${NC}"
    exit 1
fi

# Parse configuration
GIT_REPO_URL=$(grep "git_repo_url" cluster.conf | cut -d'=' -f2 | tr -d '[:space:]"')
GIT_REPO_BRANCH=$(grep "git_repo_branch" cluster.conf | cut -d'=' -f2 | tr -d '[:space:]"')

if [ -z "$GIT_REPO_URL" ] || [ -z "$GIT_REPO_BRANCH" ]; then
    echo -e "${RED}✗ Git repository configuration not found in cluster.conf${NC}"
    echo -e "${YELLOW}Please add git_repo_url and git_repo_branch to cluster.conf${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Git repository: ${GIT_REPO_URL} (branch: ${GIT_REPO_BRANCH})${NC}"

# Check if kubeconfig exists
if [ ! -f "kubeconfig" ]; then
    echo -e "${RED}✗ kubeconfig not found${NC}"
    echo -e "${YELLOW}Please run './talos-cluster.sh deploy' first${NC}"
    exit 1
fi

# Set kubeconfig
export KUBECONFIG=./kubeconfig

# Check if ArgoCD is running
echo -e "${YELLOW}🔍 Checking ArgoCD status...${NC}"
if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
    echo -e "${RED}✗ ArgoCD is not installed${NC}"
    echo -e "${YELLOW}Please run './install-argocd.sh' first${NC}"
    exit 1
fi

echo -e "${GREEN}✓ ArgoCD is running${NC}"

# Generate application manifests from templates
echo -e "${YELLOW}📝 Generating application manifests...${NC}"

# Generate Homepage manifest
echo -e "${BLUE}Generating Homepage manifest...${NC}"
sed "s|{{GIT_REPO_URL}}|${GIT_REPO_URL}|g; s|{{GIT_REPO_BRANCH}}|${GIT_REPO_BRANCH}|g" \
    apps/homepage/homepage-app.yaml.template > apps/homepage/homepage-app.yaml

# Generate Monitoring manifest
echo -e "${BLUE}Generating Monitoring manifest...${NC}"
sed "s|{{GIT_REPO_URL}}|${GIT_REPO_URL}|g; s|{{GIT_REPO_BRANCH}}|${GIT_REPO_BRANCH}|g" \
    apps/monitoring/monitoring-app.yaml.template > apps/monitoring/monitoring-app.yaml

# Deploy applications
echo -e "${YELLOW}📦 Deploying applications...${NC}"

# Deploy Homepage
echo -e "${BLUE}Deploying Homepage...${NC}"
kubectl apply -f apps/homepage/homepage-app.yaml

# Deploy Monitoring
echo -e "${BLUE}Deploying Monitoring...${NC}"
kubectl apply -f apps/monitoring/monitoring-app.yaml

echo -e "${GREEN}✅ Applications deployed successfully!${NC}"
echo ""

# Show application status
echo -e "${YELLOW}📊 Application Status:${NC}"
kubectl get applications -n argocd

echo ""
echo -e "${BLUE}🌐 Access Information:${NC}"
echo -e "  - ArgoCD UI: http://10.10.21.110:30080"
echo -e "  - Git Repository: ${GIT_REPO_URL}"
echo -e "  - Branch: ${GIT_REPO_BRANCH}"
echo -e "  - Check application status in ArgoCD UI"
echo ""

echo -e "${GREEN}🎉 GitOps setup complete!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Access ArgoCD UI to monitor applications"
echo -e "  2. Make changes to your Git repository: ${GIT_REPO_URL}"
echo -e "  3. ArgoCD will automatically sync changes"
echo -e "  4. Add more applications as needed"
