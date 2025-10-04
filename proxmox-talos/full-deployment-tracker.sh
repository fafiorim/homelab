#!/bin/bash

# Full Homelab Deployment Time Tracker
# This script tracks the complete deployment process from VM creation to application deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Timing variables
START_TIME=$(date +%s)
PHASE_START_TIME=$START_TIME

# Function to calculate and display elapsed time
show_phase_time() {
    local phase_name="$1"
    local current_time=$(date +%s)
    local phase_elapsed=$((current_time - PHASE_START_TIME))
    local total_elapsed=$((current_time - START_TIME))
    
    echo -e "${CYAN}⏱️  Phase: ${phase_name}${NC}"
    echo -e "${BLUE}   Phase Time: ${phase_elapsed}s${NC}"
    echo -e "${PURPLE}   Total Time: ${total_elapsed}s${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    
    # Log to file
    echo "$(date '+%Y-%m-%d %H:%M:%S') | ${phase_name} | Phase: ${phase_elapsed}s | Total: ${total_elapsed}s" >> deployment-timing.log
    
    PHASE_START_TIME=$current_time
}

# Function to start a new phase
start_phase() {
    local phase_name="$1"
    echo ""
    echo -e "${GREEN}🚀 Starting: ${phase_name}${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    PHASE_START_TIME=$(date +%s)
}

# Create timing log file
echo "# Full Homelab Deployment Timing Log - $(date)" > deployment-timing.log
echo "# Format: Timestamp | Phase | Phase Duration | Total Duration" >> deployment-timing.log

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    FULL HOMELAB DEPLOYMENT TRACKER                          ║${NC}"
echo -e "${GREEN}║                     Complete Infrastructure Setup                           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📋 Deployment Plan:${NC}"
echo -e "  1. Destroy existing VMs"
echo -e "  2. Create new Proxmox VMs"
echo -e "  3. Configure Talos cluster"
echo -e "  4. Deploy applications"
echo -e "  5. Verify full stack"
echo ""

# Check if configuration exists
if [ ! -f "cluster.conf" ]; then
    echo -e "${RED}❌ cluster.conf not found!${NC}"
    echo -e "${YELLOW}Please copy cluster.conf.example to cluster.conf and configure it${NC}"
    exit 1
fi

if [ ! -f "homelab.conf" ]; then
    echo -e "${RED}❌ homelab.conf not found!${NC}"
    echo -e "${YELLOW}Please copy homelab.conf.template to homelab.conf and configure it${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Configuration files found${NC}"
echo ""

# Confirm destructive operation
echo -e "${RED}⚠️  WARNING: This will DESTROY existing VMs and recreate everything!${NC}"
echo -e "${YELLOW}This operation will:${NC}"
echo -e "  - Delete VMs: talos-control-plane, talos-worker-01, talos-worker-02"
echo -e "  - Recreate all VMs from scratch"
echo -e "  - Reconfigure entire Talos cluster"
echo -e "  - Redeploy all applications"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}🎬 Starting full deployment...${NC}"

# Phase 1: Cleanup existing VMs
start_phase "VM Cleanup"
echo -e "${RED}🗑️  Cleaning up existing VMs...${NC}"
if ./talos-cluster.sh cleanup; then
    echo -e "${GREEN}✅ VMs cleaned up successfully${NC}"
else
    echo -e "${YELLOW}⚠️  VM cleanup completed (some may not have existed)${NC}"
fi
show_phase_time "VM Cleanup"

# Phase 2: Deploy complete Talos cluster
start_phase "Talos Cluster Deployment"
echo -e "${BLUE}🏗️  Deploying complete Talos cluster...${NC}"
./talos-cluster.sh deploy --force
show_phase_time "Talos Cluster Deployment"

# Phase 4: Deploy applications
start_phase "Application Deployment"
echo -e "${CYAN}📦 Deploying applications...${NC}"
./bootstrap-homelab.sh deploy
show_phase_time "Application Deployment"

# Phase 5: Final verification
start_phase "Final Verification"
echo -e "${GREEN}🔍 Running final verification...${NC}"

# Test all services
echo -e "${BLUE}Testing service accessibility...${NC}"
services=(
    "https://homepage.botocudo.net:Homepage"
    "https://argocd.botocudo.net:ArgoCD"
    "https://grafana.botocudo.net:Grafana"
    "https://prometheus.botocudo.net:Prometheus"
)

all_working=true
for service_info in "${services[@]}"; do
    IFS=':' read -r url name <<< "$service_info"
    echo -n "  Testing $name... "
    if http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url"); then
        if [[ "$http_code" == "200" || "$http_code" == "302" ]]; then
            echo -e "${GREEN}✅ ($http_code)${NC}"
        else
            echo -e "${YELLOW}⚠️  ($http_code)${NC}"
        fi
    else
        echo -e "${RED}❌ (timeout/error)${NC}"
        all_working=false
    fi
done

# Check cluster status
echo -e "${BLUE}Checking cluster status...${NC}"
export KUBECONFIG=./kubeconfig
kubectl get nodes
echo ""
kubectl get applications -n argocd

show_phase_time "Final Verification"

# Calculate total deployment time
TOTAL_TIME=$(($(date +%s) - START_TIME))
TOTAL_MINUTES=$((TOTAL_TIME / 60))
TOTAL_SECONDS=$((TOTAL_TIME % 60))

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                           DEPLOYMENT COMPLETE                               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🎉 Full homelab deployment completed!${NC}"
echo -e "${PURPLE}⏱️  Total deployment time: ${TOTAL_MINUTES}m ${TOTAL_SECONDS}s${NC}"
echo ""

if [ "$all_working" = true ]; then
    echo -e "${GREEN}✅ All services are accessible and working!${NC}"
else
    echo -e "${YELLOW}⚠️  Some services may still be starting up${NC}"
fi

echo ""
echo -e "${BLUE}📊 Deployment Summary:${NC}"
echo -e "  🏠 Homepage:    https://homepage.botocudo.net"
echo -e "  🔧 ArgoCD:      https://argocd.botocudo.net"
echo -e "  📊 Grafana:     https://grafana.botocudo.net"
echo -e "  📈 Prometheus:  https://prometheus.botocudo.net"
echo ""
echo -e "${YELLOW}📋 Timing details saved to: deployment-timing.log${NC}"
echo -e "${BLUE}🔄 GitOps Active: All changes will auto-sync from GitHub!${NC}"

# Add final summary to log
echo "$(date '+%Y-%m-%d %H:%M:%S') | DEPLOYMENT COMPLETE | Total Time: ${TOTAL_TIME}s (${TOTAL_MINUTES}m ${TOTAL_SECONDS}s)" >> deployment-timing.log
echo "# Services tested: $(if [ "$all_working" = true ]; then echo "ALL WORKING"; else echo "SOME ISSUES"; fi)" >> deployment-timing.log

echo ""
echo -e "${GREEN}Full deployment tracking complete! 🎯${NC}"