#!/bin/bash

# Update Git Repository Configuration
# This script helps users easily change their Git repository for ArgoCD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Update Git Repository Configuration${NC}"
echo ""

# Check if cluster.conf exists
if [ ! -f "cluster.conf" ]; then
    echo -e "${RED}✗ cluster.conf not found${NC}"
    echo -e "${YELLOW}Please copy cluster.conf.example to cluster.conf first${NC}"
    exit 1
fi

# Get current configuration
CURRENT_REPO=$(grep "git_repo_url" cluster.conf | cut -d'=' -f2 | tr -d '[:space:]"')
CURRENT_BRANCH=$(grep "git_repo_branch" cluster.conf | cut -d'=' -f2 | tr -d '[:space:]"')

echo -e "${YELLOW}Current Git Repository Configuration:${NC}"
echo -e "  Repository: ${CURRENT_REPO}"
echo -e "  Branch: ${CURRENT_BRANCH}"
echo ""

# Get new repository URL
read -p "Enter new Git repository URL: " NEW_REPO_URL
if [ -z "$NEW_REPO_URL" ]; then
    echo -e "${RED}✗ Repository URL cannot be empty${NC}"
    exit 1
fi

# Get new branch (default to current if not specified)
read -p "Enter branch name (default: ${CURRENT_BRANCH}): " NEW_BRANCH
if [ -z "$NEW_BRANCH" ]; then
    NEW_BRANCH="$CURRENT_BRANCH"
fi

echo ""
echo -e "${YELLOW}New Configuration:${NC}"
echo -e "  Repository: ${NEW_REPO_URL}"
echo -e "  Branch: ${NEW_BRANCH}"
echo ""

# Confirm changes
read -p "Do you want to update the configuration? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Configuration update cancelled${NC}"
    exit 0
fi

# Update cluster.conf
echo -e "${BLUE}Updating cluster.conf...${NC}"
sed -i.bak "s|git_repo_url = .*|git_repo_url = \"${NEW_REPO_URL}\"|g" cluster.conf
sed -i.bak "s|git_repo_branch = .*|git_repo_branch = \"${NEW_BRANCH}\"|g" cluster.conf

echo -e "${GREEN}✓ Configuration updated successfully${NC}"
echo ""

# Ask if user wants to redeploy applications
read -p "Do you want to redeploy applications with the new repository? (y/N): " REDEPLOY
if [[ "$REDEPLOY" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Redeploying applications...${NC}"
    ./talos-cluster.sh apps
else
    echo -e "${YELLOW}Applications not redeployed${NC}"
    echo -e "${YELLOW}Run './talos-cluster.sh apps' to deploy with the new repository${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Git repository configuration updated!${NC}"
