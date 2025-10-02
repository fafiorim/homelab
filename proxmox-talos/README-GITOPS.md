# GitOps with ArgoCD Integration

This document describes the GitOps integration using ArgoCD for the Proxmox Talos Kubernetes cluster.

## Overview

The GitOps integration provides:
- **ArgoCD**: GitOps continuous deployment tool
- **Helm Charts**: Official ArgoCD Helm chart for easy management
- **Application Management**: Deploy and manage applications via Git
- **Automated Sync**: Automatic synchronization with GitHub repository

## Architecture

```
GitHub Repository
    ↓ (GitOps)
ArgoCD (Kubernetes)
    ↓ (Deploy)
Applications (Homepage, Monitoring, etc.)
```

## Quick Start

### 1. Deploy Cluster
```bash
./talos-cluster.sh deploy --force
```

### 2. Install ArgoCD
```bash
./talos-cluster.sh argocd
```

### 3. Deploy Applications
```bash
./talos-cluster.sh apps
```

## ArgoCD Configuration

### Access Information
- **URL**: http://10.10.21.110:30080
- **Username**: admin
- **Password**: Retrieved automatically during installation

### Configuration Files
- `manifests/argocd/values.yaml` - ArgoCD Helm values
- `manifests/argocd/namespace.yaml` - ArgoCD namespace

## Application Management

### Available Applications
- **Homepage**: Dashboard application
- **Monitoring**: Prometheus, Grafana, etc.

### Application Structure
```
apps/
├── homepage/
│   └── homepage-app.yaml    # ArgoCD Application manifest
├── monitoring/
│   └── monitoring-app.yaml  # ArgoCD Application manifest
└── argocd/
    └── argocd-app.yaml      # ArgoCD self-management
```

### Adding New Applications

1. Create application directory:
```bash
mkdir -p apps/your-app
```

2. Create ArgoCD Application manifest:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: your-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/fafiorim/homelab
    targetRevision: HEAD
    path: apps/your-app
  destination:
    server: https://kubernetes.default.svc
    namespace: your-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

3. Deploy the application:
```bash
kubectl apply -f apps/your-app/your-app-app.yaml
```

## GitOps Workflow

### 1. Make Changes
- Edit application manifests in your GitHub repository
- Push changes to the repository

### 2. Automatic Sync
- ArgoCD detects changes in the repository
- Automatically syncs applications to the cluster
- Maintains desired state

### 3. Monitor Status
- Check ArgoCD UI for application status
- View logs and events
- Monitor sync status

## Commands

### Main Script Commands
```bash
./talos-cluster.sh deploy    # Deploy cluster
./talos-cluster.sh argocd    # Install ArgoCD
./talos-cluster.sh apps      # Deploy applications
./talos-cluster.sh status    # Show status
./talos-cluster.sh cleanup   # Cleanup everything
```

### Direct Scripts
```bash
./install-argocd.sh          # Install ArgoCD only
./deploy-apps.sh             # Deploy applications only
```

## Troubleshooting

### ArgoCD Not Accessible
```bash
# Check ArgoCD status
kubectl get pods -n argocd

# Check service
kubectl get svc -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

### Application Sync Issues
```bash
# Check application status
kubectl get applications -n argocd

# Check application logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Force sync application
kubectl patch application your-app -n argocd --type merge -p '{"operation":{"sync":{"syncOptions":["CreateNamespace=true"]}}}'
```

## Security

### Repository Access
- ArgoCD connects to your GitHub repository
- Uses HTTPS for secure communication
- No credentials stored in cluster

### RBAC
- ArgoCD has built-in RBAC
- Configure user access as needed
- Application-level permissions

## Best Practices

1. **Use Helm Charts**: Prefer Helm charts for complex applications
2. **Namespace Management**: Use separate namespaces for applications
3. **Resource Limits**: Set appropriate resource limits
4. **Monitoring**: Monitor application health and sync status
5. **Backup**: Regular backup of ArgoCD configuration

## Next Steps

1. **Connect GitHub Repository**: Configure ArgoCD to watch your repository
2. **Add More Applications**: Deploy additional applications via GitOps
3. **Configure Notifications**: Set up Slack/email notifications
4. **Implement CI/CD**: Integrate with GitHub Actions for automated testing
5. **Monitor Everything**: Set up comprehensive monitoring and alerting
