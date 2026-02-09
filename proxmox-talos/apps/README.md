# Applications Directory

This directory contains ArgoCD Application definitions for GitOps deployment.

## Available Applications

### 📊 Monitoring Stack (`monitoring/`)
Complete observability solution with:
- **Prometheus** - Metrics collection and storage
- **Grafana** - Dashboards and visualization (NodePort 30000)
- **Node Exporter** - System metrics from all cluster nodes

**Access**: `http://<node-ip>:30000` (admin/admin123)

### 🏠 Homepage (`homepage/`)
Dashboard application providing service overview and links.

### 📄 Paperless-NGX (`paperless/`)
Document management: https://paperless.botocudo.net

### 📷 Immich (`immich/`)
Photo/video backup with ML: https://immich.botocudo.net

### 🔀 n8n (`n8n/`)
Workflow automation (8gears Helm chart): https://n8n.botocudo.net  
Requires secret `n8n-secrets` in namespace `n8n` (see `n8n/README.md`).

### 🧪 Test Applications
- **simple-test/** - Simple test application for cluster validation
- **test-app/** - Additional test applications

## Deployment

**ArgoCD syncs everything from Git** (app-of-apps). You only need to register the bootstrap Application once; ArgoCD then syncs from the repo and creates/updates all child Applications (paperless, immich, n8n, etc.).

Deploy the bootstrap (once):
```bash
./deploy-homelab.sh 05-applications
```
Or apply only the app-of-apps:
```bash
kubectl apply -f apps/bootstrap/app-of-apps.yaml
```

After that, **ArgoCD syncs** the `homelab-apps` Application from Git; that sync creates/updates all app definitions (metallb, traefik, monitoring, homepage, paperless, immich, n8n-storage, n8n). No need to run scripts or `kubectl apply` for individual apps when you add or change them—push to Git and ArgoCD syncs.

To add a new app: add your `*-app.yaml` under `apps/<name>/`, add that file to `apps/bootstrap/kustomization.yaml`, push—ArgoCD will create the new Application and sync it.

## GitOps Configuration

All applications sync from the Git repository configured in `config.conf`:
- **Repository**: Set via `git_repo_url` in config.conf
- **Branch**: Set via `git_repo_branch` in config.conf
- **Auto-sync**: Enabled with pruning and self-healing
- **Namespace Creation**: Automatic
- **App-of-apps**: `apps/bootstrap/` defines the list of Applications; ArgoCD syncs that list from Git

## Application Structure

- **`apps/bootstrap/`** – App-of-apps: `app-of-apps.yaml` is the single Application applied once; `kustomization.yaml` lists all child Applications. ArgoCD syncs this from Git and creates/updates paperless, immich, n8n, etc.
- Each app directory (e.g. `paperless/`, `n8n/`) contains:
  - `*-app.yaml` – ArgoCD Application definition (referenced by bootstrap)
  - Kubernetes manifests or Kustomize configuration

## Monitoring

All applications are monitored by ArgoCD:
```bash
# Check application status
kubectl get applications -n argocd

# View application details
kubectl describe application <app-name> -n argocd
```