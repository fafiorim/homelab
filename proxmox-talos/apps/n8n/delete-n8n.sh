#!/usr/bin/env bash
# Remove existing n8n deployment from the cluster (ArgoCD app + namespace).
# Run from proxmox-talos with KUBECONFIG set to your cluster kubeconfig.

set -e

if [ -f "$(dirname "${BASH_SOURCE[0]}")/../../kubeconfig" ]; then
  export KUBECONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" && pwd)/kubeconfig"
fi

echo "Removing ArgoCD Application n8n (if present)..."
kubectl delete application n8n -n argocd --ignore-not-found --wait=false || true

echo "Deleting namespace n8n (all n8n resources)..."
kubectl delete namespace n8n --ignore-not-found --timeout=120s || true

echo "Done. You can redeploy with: ./apps/n8n/deploy-n8n.sh"
