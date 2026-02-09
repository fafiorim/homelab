#!/usr/bin/env bash
# Deploy n8n to the Kubernetes cluster (firefly) via ArgoCD.
# Uses the 8gears Helm chart; Traefik ingress at n8n.botocudo.net.
# Secrets (e.g. N8N_ENCRYPTION_KEY) are not in Git; create n8n-secrets in namespace n8n.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="n8n"
SECRET_NAME="n8n-secrets"

# Optional: load cluster kubeconfig (e.g. from proxmox-talos)
if [ -f "${SCRIPT_DIR}/../../cluster.conf" ]; then
  # Assume we're in proxmox-talos when running from repo root
  if [ -f "${SCRIPT_DIR}/../../kubeconfig" ]; then
    export KUBECONFIG="${SCRIPT_DIR}/../../kubeconfig"
  fi
fi

echo "Applying ArgoCD Applications for n8n (storage + Helm)..."
kubectl apply -f "${SCRIPT_DIR}/n8n-storage-app.yaml"
kubectl apply -f "${SCRIPT_DIR}/n8n-app.yaml"

echo ""
echo "Checking for required secret ${SECRET_NAME} in namespace ${NAMESPACE}..."
if ! kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
  echo ""
  echo "Secret ${SECRET_NAME} not found. Create it before n8n can start:"
  echo "  kubectl create namespace ${NAMESPACE}"
  echo "  kubectl create secret generic ${SECRET_NAME} --namespace ${NAMESPACE} \\"
  echo "    --from-literal=encryption-key=\"\$(openssl rand -hex 32)\""
  echo ""
else
  echo "Secret ${SECRET_NAME} found."
fi

echo ""
echo "n8n will sync via ArgoCD. Access when ready: https://n8n.botocudo.net"
echo "See README.md in this directory for more options and troubleshooting."
