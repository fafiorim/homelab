# n8n - Workflow Automation

n8n is a fair-code workflow automation platform with native AI capabilities. This deployment uses the [8gears Helm chart](https://github.com/8gears/n8n-helm-chart) on the Kubernetes cluster (firefly).

## Deployment

- **Helm chart**: 8gears/n8n (OCI)
- **Domain**: https://n8n.botocudo.net
- **Ingress**: Traefik with entrypoints web/websecure, Let's Encrypt (letsencrypt), HTTPS redirect
- **Persistence**: NFS at `/volume4/VM/containers/n8n/data` (same pattern as paperless/immich; 10Gi PVC)
- **Secrets**: Not committed; create Kubernetes Secret as below before or after first sync

## Prerequisites

1. **Create the NFS directory** (same as paperless/immich). On the NFS server or Proxmox (with NFS mounted, e.g. `Ugreen_NFS_VM`):
   ```bash
   mkdir -p /volume4/VM/containers/n8n/data
   chmod -R 777 /volume4/VM/containers/n8n
   ```
   If using Proxmox with NFS mount: `mkdir -p /mnt/pve/Ugreen_NFS_VM/containers/n8n/data` and set permissions as needed.

2. **Create the encryption key secret** (required for n8n). Do not commit this secret.

   ```bash
   kubectl create namespace n8n
   kubectl create secret generic n8n-secrets \
     --namespace n8n \
     --from-literal=encryption-key="$(openssl rand -hex 32)"
   ```

   Or with a specific key:

   ```bash
   kubectl create secret generic n8n-secrets \
     --namespace n8n \
     --from-literal=encryption-key="YOUR_MINIMUM_32_CHAR_SECRET_KEY"
   ```

3. Ensure DNS for `n8n.botocudo.net` points to your Traefik LoadBalancer / ingress.

## Deploy via ArgoCD

**ArgoCD syncs n8n from Git** (app-of-apps). The bootstrap Application `homelab-apps` points to `proxmox-talos/apps/bootstrap`; when ArgoCD syncs it, it creates/updates **n8n-storage** and **n8n** (and all other apps). You do **not** need to run a deploy script or `kubectl apply` for n8n—push to Git and ArgoCD syncs.

Ensure you have run the bootstrap once (e.g. `./deploy-homelab.sh 05-applications` or `kubectl apply -f apps/bootstrap/app-of-apps.yaml`). Then n8n and n8n-storage are created and synced by ArgoCD. Sync **n8n-storage** first so the PVC exists before the n8n Helm release creates pods (ArgoCD may sync both; if n8n pods wait for PVC, they will start after n8n-storage syncs).

Optional one-off (if you are not using the app-of-apps and want to register only n8n):

```bash
./apps/n8n/deploy-n8n.sh
# or: kubectl apply -f apps/n8n/n8n-storage-app.yaml && kubectl apply -f apps/n8n/n8n-app.yaml
```

Ensure the `n8n-secrets` secret exists in the `n8n` namespace before or shortly after the first sync, or the n8n pod may fail until the secret is created.

## Access

- **URL**: https://n8n.botocudo.net
- **First run**: Create an owner account in the UI.

## Persistence

This setup uses **NFS persistent storage** at `/volume4/VM/containers/n8n/data` (same method as paperless and immich):

- **PV**: `n8n-data-pv` (NFS server 10.10.21.11, path `/volume4/VM/containers/n8n/data`, 10Gi, ReadWriteMany)
- **PVC**: `n8n-data-pvc` in namespace `n8n`, used by the Helm chart via `main.persistence.existingClaim`

Workflows and data survive pod restarts. To change size or path, edit `storage.yaml` and the NFS export.

## Configuration

- **Chart values** are set in `n8n-app.yaml` under `spec.source.helm.valuesObject` (ingress, persistence, main.config, main.extraEnv).
- **Secrets**: Only references are in Git; actual values live in the `n8n-secrets` Secret (non-committed).
- To change domain, TLS, or ingress annotations, edit `n8n-app.yaml` and push; ArgoCD will sync.

## Troubleshooting

**Degraded / pod stuck in ContainerCreating**

- **NFS path missing**: If events show `mount.nfs: ... No such file or directory`, create the directory on the NFS server (10.10.21.11):
  ```bash
  ssh 10.10.21.11  # or log in to the NFS host
  sudo mkdir -p /volume4/VM/containers/n8n/data
  sudo chmod -R 777 /volume4/VM/containers/n8n
  ```
  Then delete the n8n pod so it is recreated and can mount: `kubectl delete pod -n n8n -l app.kubernetes.io/name=n8n`

**Pod not starting / CrashLoopBackOff**

- Ensure `n8n-secrets` exists and has key `encryption-key`:
  ```bash
  kubectl get secret n8n-secrets -n n8n -o jsonpath='{.data.encryption-key}' | base64 -d; echo
  ```

**404 when opening https://n8n.botocudo.net**

- The chart is configured with `proxy_hops: 1` and `WEBHOOK_URL` so n8n trusts Traefik’s `X-Forwarded-*` headers and uses the correct public URL. If you still see 404, restart the n8n pod after changing config: `kubectl rollout restart deployment -n n8n n8n`.
- Confirm the service has endpoints: `kubectl get endpoints -n n8n n8n`.

**Ingress / SSL certificate issues**

- **DNS**: Ensure `n8n.botocudo.net` resolves to the same IP as your other apps (Traefik LoadBalancer). Traefik uses Let's Encrypt DNS-01 (Cloudflare); the name must be in the same zone and correct for the cert to be issued.
- Check ingress and TLS secret:
  ```bash
  kubectl get ingress -n n8n
  kubectl describe ingress -n n8n
  kubectl get secret n8n-botocudo-net-tls -n n8n -o jsonpath='{.data.tls\\.crt}' | base64 -d | openssl x509 -noout -dates 2>/dev/null || echo "Secret missing or invalid"
  ```
- If the secret is missing or expired, delete it so Traefik requests a new cert: `kubectl delete secret n8n-botocudo-net-tls -n n8n`

**Logs**

```bash
kubectl logs -n n8n -l app.kubernetes.io/name=n8n -f
```

## Resources

- [n8n docs](https://docs.n8n.io/)
- [8gears n8n Helm chart](https://github.com/8gears/n8n-helm-chart)
- [n8n environment variables](https://docs.n8n.io/hosting/configuration/environment-variables/)
