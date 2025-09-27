# Homepage Stability Fix for Talos Kubernetes

This guide addresses the instability issues and Talos API errors you're experiencing with the Homepage application.

## Issues Identified

1. **Resource widgets causing crashes** - Missing/misconfigured metrics-server
2. **Insufficient resource limits** - Causing OOM kills
3. **Missing health checks** - No proper restart mechanisms
4. **Talos-specific API issues** - Missing required permissions and configurations
5. **Single replica** - No high availability

## Solutions Implemented

### 1. Enhanced Homepage Deployment (`homepage-complete-fixed.yaml`)

**Key improvements:**
- **Increased replicas to 2** for better availability
- **Enhanced resource limits**: 1GB memory, 1000m CPU
- **Health checks added**: Liveness, readiness, and startup probes
- **Pinned version**: Using stable v0.8.8 instead of latest tag
- **Enhanced RBAC**: Additional permissions for Talos clusters
- **Pod anti-affinity**: Distributes pods across nodes
- **Simplified widgets**: Disabled resource-intensive widgets by default

### 2. Talos-Compatible Metrics Server (`metrics-server-talos-optimized.yaml`)

**Talos-specific fixes:**
- Added `--kubelet-insecure-tls` flag (required for Talos)
- Added `insecureSkipTLSVerify: true` in APIService
- Optimized resource allocation
- Proper security context for Talos

### 3. Enhanced Troubleshooting Script (`troubleshoot-enhanced.sh`)

Comprehensive diagnostic tool that checks:
- Pod status and health
- Service configuration
- RBAC permissions  
- Metrics server functionality
- API endpoint accessibility
- Common configuration issues

## Deployment Steps

### Step 1: Deploy Fixed Metrics Server (if not working)

```bash
# Check if metrics server is working
kubectl top nodes

# If it fails, deploy the Talos-optimized version
kubectl apply -f manifests/metrics-server-talos-optimized.yaml

# Wait for it to be ready
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=300s
```

### Step 2: Deploy Fixed Homepage

```bash
# Remove existing deployment
kubectl delete -f manifests/homepage-complete.yaml

# Deploy the fixed version
kubectl apply -f manifests/homepage-complete-fixed.yaml

# Wait for deployment
kubectl wait --for=condition=available deployment homepage --timeout=300s
```

### Step 3: Verify Deployment

```bash
# Run the troubleshooting script
chmod +x scripts/troubleshoot-enhanced.sh
./scripts/troubleshoot-enhanced.sh

# Check pod status
kubectl get pods -l app.kubernetes.io/name=homepage

# Check logs
kubectl logs -l app.kubernetes.io/name=homepage --tail=50
```

### Step 4: Test Access

```bash
# Test via NodePort
curl http://10.10.21.200:30090

# Test via port-forward
kubectl port-forward service/homepage 8080:3000
# Then visit http://localhost:8080
```

## Configuration Changes Made

### Resource Limits
```yaml
# Before
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

# After
resources:
  limits:
    cpu: 1000m      # Doubled
    memory: 1Gi     # Doubled
  requests:
    cpu: 200m       # Doubled
    memory: 256Mi   # Doubled
```

### Health Checks Added
```yaml
livenessProbe:
  httpGet:
    path: /api/ping
    port: http
  initialDelaySeconds: 30
  periodSeconds: 30
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /api/ping
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 3

startupProbe:
  httpGet:
    path: /api/ping
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 12
```

### Simplified Widgets (for stability)
```yaml
widgets.yaml: |
  # Basic widgets that don't require metrics-server
  - search:
      provider: duckduckgo
      target: _blank
  
  - datetime:
      text_size: xl
      format:
        timeStyle: short
        dateStyle: short
        hourCycle: h23
  
  # Basic cluster info (non-resource intensive)
  - kubernetes:
      cluster:
        show: true
        showLabel: true
        label: "Talos Cluster"
      nodes:
        show: true
        showLabel: true
  
  # Resource widgets commented out until metrics-server is stable
  # - resources:
  #     backend: resources
  #     expanded: true
  #     cpu: true
  #     memory: true
  #     disk: /
```

## Enabling Resource Widgets (Optional)

Once metrics-server is stable, you can re-enable resource widgets:

1. Edit the ConfigMap:
```bash
kubectl edit configmap homepage
```

2. Uncomment the resources widget in the `widgets.yaml` section

3. Restart the deployment:
```bash
kubectl rollout restart deployment homepage
```

## Monitoring and Maintenance

### Check Application Health
```bash
# Pod status
kubectl get pods -l app.kubernetes.io/name=homepage

# Resource usage
kubectl top pods -l app.kubernetes.io/name=homepage

# Recent events
kubectl get events --field-selector involvedObject.name=homepage --sort-by='.lastTimestamp' | tail -10
```

### Log Monitoring
```bash
# Stream logs
kubectl logs -l app.kubernetes.io/name=homepage -f

# Check for errors
kubectl logs -l app.kubernetes.io/name=homepage --tail=100 | grep -i error
```

### Performance Tuning

If you still experience issues:

1. **Increase replicas** for better load distribution:
```bash
kubectl scale deployment homepage --replicas=3
```

2. **Further increase resource limits** if needed:
```yaml
resources:
  limits:
    cpu: 2000m
    memory: 2Gi
```

3. **Disable problematic widgets** temporarily:
   - Comment out `kubernetes` widget if API calls are failing
   - Remove `resources` widget if metrics are unreliable

## Talos-Specific Notes

- **TLS Issues**: Talos uses different certificate handling, requiring `--kubelet-insecure-tls`
- **API Access**: Some Kubernetes APIs may behave differently on Talos
- **Resource Monitoring**: May require additional configuration for proper metrics collection
- **Node Access**: Ensure proper network policies for NodePort access

## Common Issues and Solutions

| Issue | Symptom | Solution |
|-------|---------|----------|
| Pods crashing | CrashLoopBackOff | Check resource limits, increase memory |
| API timeouts | Widgets showing "-" | Verify RBAC permissions, check metrics-server |
| NodePort inaccessible | Connection refused | Check service configuration, verify node firewall |
| Resource widgets failing | No CPU/memory data | Deploy Talos-compatible metrics-server |
| High resource usage | Pods using too much CPU/memory | Disable resource-intensive widgets |

The fixed configuration should provide much better stability while maintaining functionality appropriate for a Talos Kubernetes environment.