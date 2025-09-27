# Homepage Kubernetes Deployment Guide

A comprehensive guide to deploy [Homepage](https://github.com/gethomepage/homepage) - a highly customizable application dashboard - on Kubernetes clusters.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Repository Structure](#repository-structure)
- [Deployment Methods](#deployment-methods)
- [Configuration](#configuration)
- [Access Methods](#access-methods)
- [Metrics Server Setup](#metrics-server-setup)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)
- [Maintenance](#maintenance)

## Prerequisites

- Kubernetes cluster (tested on v1.34.0)
- `kubectl` configured to access your cluster
- Basic understanding of Kubernetes resources
- Optional: `make` for simplified commands

## GitOps Workflow

This repository is designed for GitOps - any changes pushed to GitHub will automatically deploy to your lab environment.

### How It Works

1. **Edit configuration files** in the repository
2. **Commit and push** to GitHub
3. **GitHub Actions** automatically deploys changes to your cluster
4. **Homepage updates** with new configuration

### Making Changes

#### Adding Services
Edit `config/services.yaml`:
```bash
git clone https://github.com/fafiorim/homepage-k8s.git
cd homepage-k8s
vim config/services.yaml  # Add your services
git add config/services.yaml
git commit -m "Add Jellyfin and Pi-hole services"
git push origin main
# Deployment happens automatically
```

#### Updating Settings
```bash
vim config/settings.yaml  # Change theme, layout, etc.
git commit -am "Update theme to light mode"
git push origin main
```

#### Modifying Widgets
```bash
vim config/widgets.yaml  # Add/remove widgets
git commit -am "Add weather widget"
git push origin main
```

## Repository Structure

```
homepage-k8s/
├── README.md                          # Main documentation
├── CHANGELOG.md                       # Version history  
├── .gitignore                         # Git ignore rules
├── Makefile                          # Common operations
├── kustomization.yaml                # Kustomize configuration
├── deploy.sh                         # Main deployment script
├── quickstart.sh                     # Quick deployment script
├── manifests/
│   ├── homepage-complete.yaml        # Complete deployment manifest
│   ├── service-loadbalancer.yaml     # LoadBalancer service option
│   └── metrics-server-talos.yaml     # Metrics server for Talos Linux
├── examples/
│   ├── services-example.yaml         # Example service configurations
│   └── widgets-example.yaml          # Example widget configurations
├── patches/
│   └── security-context.yaml         # Security hardening patches
└── scripts/
    └── troubleshoot.sh               # Troubleshooting script
```

## Deployment Methods

### Method 1: Complete Kubernetes Manifests (Recommended)

Deploy all resources with proper RBAC permissions:

```bash
kubectl apply -f manifests/homepage-complete.yaml
```

### Method 2: Separate Resource Files

Deploy individual components for more granular control:

```bash
# Deploy in order
kubectl apply -f manifests/serviceaccount.yaml
kubectl apply -f manifests/configmap.yaml
kubectl apply -f manifests/rbac.yaml
kubectl apply -f manifests/deployment.yaml
kubectl apply -f manifests/service.yaml
kubectl apply -f manifests/ingress.yaml  # Optional
```

Note: For Method 2, you'll need to split the complete manifest into separate files.

## Configuration

### Environment Variables

The deployment requires the `HOMEPAGE_ALLOWED_HOSTS` environment variable:

```bash
kubectl set env deployment/homepage HOMEPAGE_ALLOWED_HOSTS="your-domain.com:30090,localhost:3000"
```

### ConfigMap Structure

The ConfigMap contains six configuration files:

- `settings.yaml` - General settings and themes
- `services.yaml` - Application services to display
- `bookmarks.yaml` - Quick access bookmarks
- `widgets.yaml` - Information widgets
- `kubernetes.yaml` - Kubernetes integration settings
- `docker.yaml` - Docker integration (usually empty for K8s)

### Basic Configuration Example

Edit the ConfigMap to customize your dashboard:

```bash
kubectl edit configmap homepage
```

Example `services.yaml`:
```yaml
- Development:
    - GitHub:
        href: https://github.com/your-org
        description: Source code repositories
        icon: github.png
    - GitLab:
        href: https://gitlab.company.com
        description: Internal GitLab instance
        icon: gitlab.png

- Monitoring:
    - Grafana:
        href: https://grafana.company.com
        description: Metrics and dashboards
        icon: grafana.png
        widget:
          type: grafana
          url: https://grafana.company.com
          username: admin
          password: your-password
```

## Access Methods

### NodePort (Default - No DNS Required)

The deployment creates a NodePort service on port 30090:

```bash
# Get node IPs
kubectl get nodes -o wide

# Access via any node IP
http://NODE_IP:30090
```

### LoadBalancer (Cloud Environments)

For cloud deployments with LoadBalancer support:

```bash
kubectl apply -f manifests/service-loadbalancer.yaml

# Get external IP
kubectl get svc homepage-lb
```

### Ingress (Domain-based Access)

For domain-based access with ingress controller:

1. Update `manifests/ingress.yaml` with your domain
2. Apply the ingress:
   ```bash
   kubectl apply -f manifests/ingress.yaml
   ```
3. Configure DNS to point to your ingress controller

### Port Forward (Development/Testing)

For local testing:

```bash
kubectl port-forward svc/homepage 3000:3000
# Access: http://localhost:3000
```

## Metrics Server Setup

Homepage's resource and Kubernetes widgets require metrics-server to display CPU and memory usage. Without it, you'll see errors like:

```
error: <widget> Error getting metrics, ensure you have metrics-server installed
```

### Quick Fix: Disable Metrics Widgets

If you want to stop the errors immediately:

```bash
make disable-metrics-widgets
```

### Install Metrics Server

#### Standard Installation

For most Kubernetes distributions:
```bash
make metrics-server
```

#### Talos Linux Installation

For Talos Linux clusters, use the specialized configuration:
```bash
make metrics-server-talos
```

#### Fix Existing Installation

If you already have metrics-server but it's not working with Talos:
```bash
make fix-metrics-talos
```

#### Manual Installation

For standard clusters:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

For Talos Linux:
```bash
kubectl apply -f manifests/metrics-server-talos.yaml
```

#### Verify Installation

```bash
make check-metrics
# Or manually:
kubectl top nodes
kubectl top pods
```

### Troubleshooting Metrics

If metrics are still not working:

```bash
# Run the troubleshooting script
./scripts/troubleshoot.sh

# Check metrics-server logs
kubectl logs -n kube-system deployment/metrics-server

# Test metrics API directly
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
```

## Customization

### Adding Services

1. Edit the ConfigMap:
   ```bash
   kubectl edit configmap homepage
   ```

2. Add your services to `services.yaml`
3. Restart the deployment:
   ```bash
   kubectl rollout restart deployment homepage
   ```

### Kubernetes Widget Integration

The deployment includes RBAC permissions for Kubernetes integration. Configure in `widgets.yaml`:

```yaml
- kubernetes:
    cluster:
      show: true
      cpu: true
      memory: true
      showLabel: true
      label: "cluster"
    nodes:
      show: true
      cpu: true
      memory: true
      showLabel: true
```

### Service Discovery

Homepage can automatically discover services using ingress annotations:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-service
  annotations:
    gethomepage.dev/enabled: "true"
    gethomepage.dev/description: "My Application"
    gethomepage.dev/group: "Applications"
    gethomepage.dev/icon: "app-icon.png"
    gethomepage.dev/name: "My App"
spec:
  # ... ingress configuration
```

### Themes and Styling

Customize appearance in `settings.yaml`:

```yaml
title: "My Dashboard"
theme: dark
color: slate
background: https://images.unsplash.com/photo-1502790671504-542ad42d5189
cardBlur: md
headerStyle: boxed
hideVersion: true
```

## Troubleshooting

### Automated Troubleshooting

Run the comprehensive troubleshooting script:

```bash
./scripts/troubleshoot.sh
```

This script will check:
- Deployment status
- Service configuration  
- ConfigMap settings
- Metrics server availability
- Application logs
- RBAC permissions
- Common issues and solutions

### Common Issues

1. **Pod not starting:**
   ```bash
   kubectl describe pod -l app.kubernetes.io/name=homepage
   kubectl logs -l app.kubernetes.io/name=homepage
   ```

2. **Permission denied errors:**
   - Verify RBAC resources are applied
   - Check ServiceAccount is correctly referenced

3. **Configuration not updating:**
   ```bash
   # Force restart after ConfigMap changes
   kubectl rollout restart deployment homepage
   ```

4. **Service discovery not working:**
   - Verify ingress annotations
   - Check RBAC permissions for ingress resources

5. **Resource widgets showing dashes:**
   - Ensure metrics-server is installed
   - Verify RBAC permissions for metrics.k8s.io

### Metrics Server Issues

Homepage's resource and Kubernetes widgets require metrics-server to display CPU and memory usage. If you see errors like:

```
error: <widget> Error getting metrics, ensure you have metrics-server installed
```

#### Quick Fix: Disable Metrics Widgets

Edit the ConfigMap to remove metrics-dependent widgets:

```bash
kubectl edit configmap homepage
```

Replace widgets.yaml with:
```yaml
widgets.yaml: |
  - search:
      provider: duckduckgo
      target: _blank
  
  - datetime:
      text_size: xl
      format:
        timeStyle: short
        dateStyle: short
        hourCycle: h23
  
  - kubernetes:
      cluster:
        show: true
        cpu: false
        memory: false
        showLabel: true
        label: "cluster"
      nodes:
        show: false
```

#### Install Metrics Server

For most Kubernetes distributions:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

For local development clusters (kind, minikube, etc.):
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

#### Talos Linux Specific Configuration

For Talos Linux clusters, metrics-server requires additional configuration:

```bash
# Patch metrics-server for Talos compatibility
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  },
  {
    "op": "add", 
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-", 
    "value": "--kubelet-use-node-status-port"
  }
]'
```

Or apply a complete Talos-compatible configuration:
```bash
kubectl apply -f manifests/metrics-server-talos.yaml
```

#### Verify Metrics Server

```bash
# Check if metrics-server is running
kubectl get pods -n kube-system | grep metrics-server

# Test metrics availability
kubectl top nodes
kubectl top pods

# Check metrics-server logs if issues persist
kubectl logs -n kube-system deployment/metrics-server
```

### Using Make Commands

The repository includes helpful Make commands:

```bash
# Check current status
make status

# Install metrics-server
make metrics-server              # Standard installation
make metrics-server-talos        # Talos-specific installation
make fix-metrics-talos          # Fix existing installation for Talos
make check-metrics              # Verify metrics availability

# Disable widgets if needed
make disable-metrics-widgets

# Other useful commands
make logs                       # View application logs
make config                     # Edit configuration
make restart                    # Restart deployment
make get-access                 # Show access information
```

### Debugging Commands

```bash
# Check all resources
kubectl get all -l app.kubernetes.io/name=homepage

# Check ConfigMap
kubectl get configmap homepage -o yaml

# Check RBAC
kubectl auth can-i get pods --as=system:serviceaccount:default:homepage

# Test service connectivity
kubectl port-forward svc/homepage 3000:3000

# Check metrics availability
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods
```

## Security Considerations

### Important Security Notes

1. **No Built-in Authentication:** Homepage doesn't include authentication. Deploy behind:
   - Reverse proxy with authentication
   - VPN
   - Network policies restricting access

2. **API Key Exposure:** Widget configurations may contain API keys. Use:
   - Kubernetes secrets for sensitive data
   - Network policies to restrict egress
   - Least-privilege RBAC

3. **Service Account Permissions:** The included RBAC provides cluster-wide read access for Kubernetes resources. Review and adjust permissions based on your security requirements.

### Recommended Security Hardening

```yaml
# Example: Restrict to specific namespaces
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: homepage-production
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list"]
```

## Maintenance

### Updating Homepage

```bash
# Update to latest image
kubectl set image deployment/homepage homepage=ghcr.io/gethomepage/homepage:latest

# Check rollout status
kubectl rollout status deployment/homepage
```

### Backup Configuration

```bash
# Export current configuration
kubectl get configmap homepage -o yaml > homepage-config-backup.yaml
```

### Monitoring

Monitor Homepage deployment:

```bash
# Check deployment status
kubectl get deployment homepage

# Monitor resource usage
kubectl top pods -l app.kubernetes.io/name=homepage

# Check service endpoints
kubectl get endpoints homepage
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes
4. Submit a pull request

## License

This deployment configuration is provided under the MIT License. Homepage itself is licensed under the GNU GPL v3.

## References

- [Homepage Documentation](https://gethomepage.dev/)
- [Homepage GitHub Repository](https://github.com/gethomepage/homepage)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

---

**Note:** Always review security implications before deploying in production environments. Homepage provides access to potentially sensitive information and should be properly secured.