# Monitoring Stack Documentation

This document describes the comprehensive monitoring solution deployed via ArgoCD in the Talos Kubernetes cluster.

## Overview

The monitoring stack provides full observability for your Kubernetes cluster with:
- **Prometheus** - Metrics collection, storage, and alerting
- **Grafana** - Visualization and dashboards
- **Node Exporter** - System metrics from all cluster nodes

## Components

### 1. Prometheus (Metrics Collection)
- **Image**: `prom/prometheus:v2.45.0`
- **Port**: 9090
- **Storage**: Ephemeral (consider persistent storage for production)
- **Configuration**: Automatically discovers Kubernetes services and pods
- **RBAC**: ServiceAccount with cluster-wide read permissions

#### Scrape Targets
- Kubernetes API Server
- Kubernetes Nodes
- Node Exporter (system metrics)
- Any pod with `prometheus.io/scrape: "true"` annotation

### 2. Grafana (Visualization)
- **Image**: `grafana/grafana:10.1.0`
- **Port**: 3000 (internal), 30000 (NodePort)
- **Access**: Any cluster node IP on port 30000
- **Default Credentials**: 
  - Username: `admin`
  - Password: `admin123`
- **Datasource**: Pre-configured Prometheus connection

### 3. Node Exporter (System Metrics)
- **Image**: `prom/node-exporter:v1.6.1`
- **Deployment**: DaemonSet (runs on all nodes)
- **Port**: 9100
- **Metrics**: CPU, Memory, Disk, Network, and system statistics
- **Host Access**: Uses privileged security context for host metrics

## Security Configuration

The monitoring namespace uses **privileged** Pod Security Standards to allow Node Exporter to:
- Access host network (`hostNetwork: true`)
- Access host process namespace (`hostPID: true`) 
- Mount host paths (`/proc`, `/sys`, `/`)
- Use host ports (9100)

```yaml
labels:
  pod-security.kubernetes.io/enforce: privileged
  pod-security.kubernetes.io/audit: privileged
  pod-security.kubernetes.io/warn: privileged
```

## Deployment

### Via ArgoCD (Recommended)
```bash
# Deploy monitoring stack
./talos-cluster.sh apps

# Check deployment status
kubectl get applications -n argocd
kubectl get pods -n monitoring
```

### Manual Deployment
```bash
# Apply all monitoring manifests
kubectl apply -k apps/monitoring/
```

## Access and Usage

### Grafana Dashboard
1. **Access URL**: `http://<node-ip>:30000`
   - Example: `http://10.10.21.110:30000`
2. **Login**: admin / admin123
3. **Datasource**: Prometheus is pre-configured
4. **Import Dashboards**: Use Grafana community dashboards for Kubernetes

### Prometheus Web UI
- **Internal Access**: `http://prometheus.monitoring.svc.cluster.local:9090`
- **Port Forward**: `kubectl port-forward -n monitoring svc/prometheus 9090:9090`

## Recommended Grafana Dashboards

Import these community dashboards for comprehensive monitoring:

1. **Kubernetes Cluster Monitoring** (ID: 7249)
2. **Node Exporter Full** (ID: 1860)
3. **Kubernetes Pod Monitoring** (ID: 6417)
4. **Prometheus Stats** (ID: 2)

## Files Structure

```
apps/monitoring/
├── monitoring-app.yaml         # ArgoCD Application definition
├── namespace.yaml              # Monitoring namespace with security policy
├── rbac.yaml                   # ServiceAccount and RBAC for Prometheus
├── prometheus.yaml             # Prometheus deployment and configuration
├── grafana.yaml                # Grafana deployment with datasource
├── node-exporter.yaml          # Node Exporter DaemonSet
└── kustomization.yaml          # Kustomize configuration
```

## Configuration Customization

### Prometheus Configuration
Edit `prometheus.yaml` ConfigMap section to:
- Add custom scrape targets
- Configure retention policies
- Add recording rules
- Configure alerting rules

### Grafana Configuration
- **Password**: Change default admin password in `grafana.yaml`
- **Plugins**: Add plugins via `GF_INSTALL_PLUGINS` environment variable
- **Datasources**: Add additional datasources via ConfigMap

### Resource Limits
Current resource allocation:
- **Prometheus**: 256Mi-512Mi memory, 200m-500m CPU
- **Grafana**: 128Mi-256Mi memory, 100m-200m CPU  
- **Node Exporter**: 64Mi-128Mi memory, 50m-100m CPU

## Troubleshooting

### Node Exporter Not Starting
If Node Exporter pods fail with security policy violations:
```bash
# Check namespace security policy
kubectl get namespace monitoring -o yaml | grep pod-security

# Ensure privileged policy is set
kubectl label namespace monitoring pod-security.kubernetes.io/enforce=privileged
```

### Grafana Login Issues
```bash
# Reset admin password
kubectl exec -n monitoring deployment/grafana -- grafana-cli admin reset-admin-password newpassword
```

### Prometheus Discovery Issues
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090/targets
```

## Production Considerations

1. **Persistent Storage**: Configure PersistentVolumes for Prometheus and Grafana
2. **High Availability**: Deploy multiple Prometheus replicas with shared storage
3. **Security**: 
   - Change default passwords
   - Configure RBAC restrictions
   - Use TLS for external access
4. **Alerting**: Configure Alertmanager for alert routing
5. **Backup**: Regular backup of Grafana dashboards and Prometheus data
6. **Resource Scaling**: Adjust resource limits based on cluster size

## Monitoring Metrics

Key metrics available:
- **Node Metrics**: CPU, memory, disk, network usage per node
- **Pod Metrics**: Resource usage, restart counts, status
- **Cluster Metrics**: API server performance, etcd metrics
- **Custom Metrics**: Application-specific metrics via annotations

## Integration with ArgoCD

The monitoring stack is deployed as an ArgoCD Application:
- **Source**: Git repository at `proxmox-talos/apps/monitoring`
- **Sync Policy**: Automatic with pruning and self-healing
- **Namespace**: `monitoring` (created automatically)
- **Health**: Monitored by ArgoCD for deployment status