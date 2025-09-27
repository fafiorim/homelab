#!/bin/bash

# Homepage Kubernetes Quick Start
# This script performs a rapid deployment of Homepage

set -e

echo "🚀 Homepage Kubernetes Quick Start"
echo "=================================="
echo

# Check prerequisites
echo "📋 Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster."
    exit 1
fi

echo "✅ Prerequisites satisfied"
echo

# Deploy Homepage
echo "🔧 Deploying Homepage..."
kubectl apply -f manifests/homepage-complete.yaml

echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/homepage

# Get access information
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
ALLOWED_HOSTS="localhost:3000,$NODE_IP:30090"

# Configure allowed hosts
echo "🔐 Configuring access permissions..."
kubectl set env deployment/homepage HOMEPAGE_ALLOWED_HOSTS="$ALLOWED_HOSTS"

# Wait for rollout
kubectl rollout status deployment/homepage --timeout=120s

echo
echo "🎉 Homepage deployment completed!"
echo
echo "📍 Access Information:"
echo "   NodePort: http://$NODE_IP:30090"
echo "   Port-forward: kubectl port-forward svc/homepage 3000:3000"
echo "                Then access: http://localhost:3000"
echo
echo "🛠️  Management Commands:"
echo "   Status: kubectl get pods -l app.kubernetes.io/name=homepage"
echo "   Logs: kubectl logs -l app.kubernetes.io/name=homepage"
echo "   Config: kubectl edit configmap homepage"
echo "   Restart: kubectl rollout restart deployment/homepage"
echo
echo "📚 For more options, see: ./deploy.sh --help"
echo "📖 Full documentation: README.md"
echo

# Optional: Open browser (uncomment if desired)
# if command -v open &> /dev/null; then
#     echo "🌐 Opening in browser..."
#     open "http://$NODE_IP:30090"
# fi