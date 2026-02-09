# OpenClaw — Personal AI Assistant

[OpenClaw](https://github.com/openclaw/openclaw) is a personal AI assistant you run on your own infrastructure. It provides a Gateway (control plane) and can connect to WhatsApp, Telegram, Slack, Discord, Google Chat, Signal, iMessage, and more.

- **Docs:** [openclaw.ai](https://openclaw.ai) · [GitHub](https://github.com/openclaw/openclaw)
- **URL:** https://openclaw.botocudo.net

## Architecture

This deployment runs the OpenClaw Gateway in Kubernetes with:
- **Gateway Port:** 18789 (main control plane)
- **Bridge Port:** 18790 (channel connections)
- **Persistence:** NFS storage for config and workspace
- **Ingress:** Traefik with automatic Let's Encrypt SSL
- **Authentication:** Optional token-based auth via secrets

## Prerequisites

### 1. NFS Storage

Create the NFS directory on your NFS server (10.10.21.11):

```bash
mkdir -p /volume4/VM/containers/openclaw/data
chmod -R 777 /volume4/VM/containers/openclaw
```

### 2. Container Image

The deployment uses `ghcr.io/openclaw/openclaw:latest`. If this image is not available publicly, you'll need to build and push it:

```bash
# Clone the OpenClaw repository
git clone https://github.com/openclaw/openclaw.git
cd openclaw

# Build the Docker image
docker build -t ghcr.io/openclaw/openclaw:latest .

# Push to your registry (or use local registry)
docker push ghcr.io/openclaw/openclaw:latest
```

Alternatively, update the image reference in [deployment.yaml](deployment.yaml) to use your own registry.

### 3. Gateway Authentication (Optional but Recommended)

Create a secret for gateway authentication:

```bash
# Create the namespace first
kubectl create namespace openclaw

# Option A: Token-based authentication (recommended)
kubectl create secret generic openclaw-secrets -n openclaw \
  --from-literal=gateway-token="$(openssl rand -hex 24)"

# Option B: Password-based authentication
# kubectl create secret generic openclaw-secrets -n openclaw \
#   --from-literal=gateway-password="your-secure-password"
```

To retrieve the token later:

```bash
kubectl get secret openclaw-secrets -n openclaw \
  -o jsonpath='{.data.gateway-token}' | base64 -d
```

### 4. DNS Configuration

Point `openclaw.botocudo.net` to your Traefik LoadBalancer IP. The ingress will automatically request a Let's Encrypt SSL certificate.

## Deployment

### Via ArgoCD (Recommended)

If you have ArgoCD set up with the app-of-apps pattern:

```bash
# Apply the ArgoCD Application
kubectl apply -f openclaw-app.yaml

# Watch the deployment
kubectl get pods -n openclaw -w
```

### Manual Deployment

Using kustomize:

```bash
kubectl apply -k .
```

Or apply files individually:

```bash
kubectl apply -f namespace.yaml
kubectl apply -f storage.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
```

## Post-Deployment Setup

### 1. Access the Gateway

Once deployed, access the OpenClaw Control UI at:
- **URL:** https://openclaw.botocudo.net
- **Auth:** Use the gateway token or password from the secret

### 2. Run Onboarding

Install the OpenClaw CLI on your local machine and run onboarding:

```bash
# Install OpenClaw globally
npm install -g openclaw@latest

# Run onboarding wizard
openclaw onboard
```

When prompted:
- **Gateway URL:** `https://openclaw.botocudo.net` or `wss://openclaw.botocudo.net`
- **Authentication:** Use the token/password from the secret

The onboarding wizard will help you:
- Configure AI models (Claude, GPT, or local models)
- Set up messaging channels (WhatsApp, Telegram, etc.)
- Configure tools and integrations

## Configuration

### Resource Limits

Default resource allocation:
- **Requests:** 256Mi memory, 100m CPU
- **Limits:** 512Mi memory, 500m CPU

Adjust in [deployment.yaml](deployment.yaml) if needed for your workload.

### Storage

Default storage: 5Gi NFS volume at `/home/node/.openclaw`

This stores:
- Configuration files (`openclaw.json`)
- Workspace data
- Channel state
- Session history

## Verification

Check deployment status:

```bash
# Check pods
kubectl get pods -n openclaw

# Check logs
kubectl logs -n openclaw -l app=openclaw -f

# Check service
kubectl get svc -n openclaw

# Check ingress
kubectl get ingress -n openclaw
```

Expected output:
```
NAME                               READY   STATUS    RESTARTS   AGE
openclaw-gateway-xxxxxxxxxx-xxxxx  1/1     Running   0          2m
```

## Troubleshooting

### ImagePullBackOff

The image `ghcr.io/openclaw/openclaw:latest` may not be publicly available yet. Build from source:

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
docker build -t your-registry/openclaw:latest .
docker push your-registry/openclaw:latest
```

Then update [deployment.yaml](deployment.yaml) with your image reference.

### CreateContainerConfigError

The `openclaw-secrets` secret is missing. Create it:

```bash
kubectl create secret generic openclaw-secrets -n openclaw \
  --from-literal=gateway-token="$(openssl rand -hex 24)"
```

Or set `optional: false` to `optional: true` in the deployment if you don't want authentication.

### Pod Not Ready / CrashLoopBackOff

Check logs for errors:

```bash
kubectl logs -n openclaw -l app=openclaw
```

Common issues:
- **NFS mount issues:** Verify the NFS path exists and is accessible
- **Permission errors:** Run the init container to fix permissions
- **Port conflicts:** Ensure ports 18789 and 18790 are available

### PVC Not Binding

Check PV/PVC status:

```bash
kubectl get pv,pvc -n openclaw
```

Verify:
- NFS server is accessible from the cluster
- NFS path exists: `/volume4/VM/containers/openclaw/data`
- Permissions are correct (777 or appropriate)

### Cannot Access via HTTPS

1. Check ingress:
   ```bash
   kubectl get ingress -n openclaw
   kubectl describe ingress openclaw-ingress -n openclaw
   ```

2. Verify DNS points to Traefik LoadBalancer IP

3. Check Traefik certificate:
   ```bash
   kubectl get certificate -n openclaw
   ```

## Channels Configuration

After onboarding, configure channels through the OpenClaw CLI or web UI:

### Supported Channels
- WhatsApp
- Telegram
- Slack
- Discord
- Google Chat
- Signal
- BlueBubbles (iMessage)
- Microsoft Teams
- Matrix
- WebChat

Each channel requires specific API credentials or setup. Refer to the [OpenClaw documentation](https://docs.openclaw.ai) for channel-specific configuration.

## Updating

To update OpenClaw to a newer version:

```bash
# If using latest tag, restart deployment to pull new image
kubectl rollout restart deployment/openclaw-gateway -n openclaw

# Or update to specific version in deployment.yaml
# Then apply changes
kubectl apply -f deployment.yaml
```

## Uninstalling

To completely remove OpenClaw:

```bash
# Via ArgoCD
kubectl delete application openclaw -n argocd

# Or manually
kubectl delete -k .

# Remove PV (optional, keeps data)
# kubectl delete pv openclaw-data-pv
```

## Advanced Configuration

### Environment Variables

Additional environment variables can be added to [deployment.yaml](deployment.yaml):

```yaml
env:
- name: OPENCLAW_GATEWAY_BIND
  value: "0.0.0.0"  # Allow external connections
- name: OPENCLAW_LOG_LEVEL
  value: "debug"    # Increase logging
```

### Multiple Replicas

OpenClaw Gateway should run with `replicas: 1` to maintain session state. For high availability, consider:
- Running multiple instances with separate configurations
- Using persistent sessions with shared storage
- Implementing custom session synchronization

## Support

- **Documentation:** https://docs.openclaw.ai
- **GitHub:** https://github.com/openclaw/openclaw
- **Discord:** https://discord.com/invite/clawd

## License

OpenClaw is open-source. Check the [official repository](https://github.com/openclaw/openclaw) for license details.