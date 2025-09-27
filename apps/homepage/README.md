# Homepage Kubernetes Deployment Guide

A comprehensive guide to deploy [Homepage](https://github.com/gethomepage/homepage) - a highly customizable application dashboard - on Kubernetes clusters.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Methods](#deployment-methods)
- [Configuration](#configuration)
- [Access Methods](#access-methods)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)
- [Maintenance](#maintenance)

## Prerequisites

- Kubernetes cluster (tested on v1.34.0)
- `kubectl` configured to access your cluster
- Basic understanding of Kubernetes resources

## Quick Start

1. **Clone this repository:**
   ```bash
   git clone <your-repo-url>
   cd homepage-k8s
   ```

2. **Deploy using manifests:**
   ```bash
   kubectl apply -f manifests/
   ```

3. **Get your node IP:**
   ```bash
   kubectl get nodes -o wide
   ```

4. **Update allowed hosts:**
   ```bash
   # Replace with your actual node IP
   kubectl set env deployment/homepage HOMEPAGE_ALLOWED_HOSTS="YOUR_NODE_IP:30090,localhost:3000"
   ```

5. **Access Homepage:**
   Open `http://YOUR_NODE_IP:30090` in your browser

## Deployment Methods

### Method 1: Complete Kubernetes Manifests (Recommended)

Deploy all resources with proper RBAC permissions:

```bash
kubectl apply -f manifests/homepage-complete.yaml
```

### Method 2: Helm Chart

```bash
# Add repository
helm repo add jameswynn https://jameswynn.github.io/helm-charts
helm repo update

# Install
helm install homepage jameswynn/homepage
```

### Method 3: Separate Resource Files

Deploy individual components:

```bash
kubectl apply -f manifests/serviceaccount.yaml
kubectl apply -f manifests/configmap.yaml
kubectl apply -f manifests/rbac.yaml
kubectl apply -f manifests/deployment.yaml
kubectl apply -f manifests/service.yaml
kubectl apply -f manifests/ingress.yaml  # Optional
```

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