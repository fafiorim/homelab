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

### 🧪 Test Applications
- **simple-test/** - Simple test application for cluster validation
- **test-app/** - Additional test applications

## Deployment

Deploy all applications via the main script:
```bash
./talos-cluster.sh apps
```

Or deploy individual applications:
```bash
kubectl apply -f apps/monitoring/monitoring-app.yaml
kubectl apply -f apps/homepage/homepage-app.yaml
```

## GitOps Configuration

All applications sync from the Git repository configured in `config.conf`:
- **Repository**: Set via `git_repo_url` in config.conf
- **Branch**: Set via `git_repo_branch` in config.conf
- **Auto-sync**: Enabled with pruning and self-healing
- **Namespace Creation**: Automatic

## Application Structure

Each application directory contains:
- `*-app.yaml` - ArgoCD Application definition
- `*-app.yaml.template` - Template for Git repository substitution
- Kubernetes manifests or Kustomize configuration

## Monitoring

All applications are monitored by ArgoCD:
```bash
# Check application status
kubectl get applications -n argocd

# View application details
kubectl describe application <app-name> -n argocd
```