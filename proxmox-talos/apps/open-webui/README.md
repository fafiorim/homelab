# Open WebUI

Open WebUI is a self-hosted ChatGPT-style web interface for LLMs. This deployment connects to the Ollama instance running on the DGX Spark machine.

## Quick Access

- **URL**: https://open-webui.botocudo.net
- **Status**: ✅ Deployed and running
- **Backend**: NVIDIA DGX Spark (10.10.21.6) running Ollama
- **Models**: llama3.2, mistral (auto-detected from DGX)

## Configuration

### Ollama Backend

- **Ollama Base URL**: `http://10.10.21.6:11434`
- **DGX Machine IP**: `10.10.21.6` (NVIDIA DGX Spark)
- **Available Models**: llama3.2, mistral (and any other models pulled on the DGX)
- **Authentication**: None required
- **GPU**: Models run on NVIDIA DGX Spark GPUs
- **Connection**: Direct HTTP from Open WebUI pod to DGX on the same network (10.10.21.x)
- **Endpoint Configuration**: Set via `OLLAMA_BASE_URL` environment variable in [open-webui.yaml](open-webui.yaml:28-29)

### Web Interface

- **URL**: https://open-webui.botocudo.net
- **TLS**: Automatic Let's Encrypt certificate via Traefik
- **Port**: 8080 (internal)

### Storage

- **Type**: NFS
- **Server**: 10.10.21.11
- **Path**: /volume4/VM/containers/open-webui/data
- **Size**: 10Gi
- **Purpose**: User data, conversations, and configurations

## Resources

### Container Resources

- **Requests**: 200m CPU, 512Mi memory
- **Limits**: 1000m CPU, 2Gi memory

### Health Checks

- **Liveness Probe**: HTTP GET /health on port 8080
- **Readiness Probe**: HTTP GET /health on port 8080

## First-Time Setup

### Prerequisites

Create the NFS storage directory on your NAS (10.10.21.11):
```bash
sudo mkdir -p /volume4/VM/containers/open-webui/data
sudo chmod 777 /volume4/VM/containers/open-webui/data
```

### Deployment

1. **ArgoCD** will automatically deploy Open WebUI when you push these changes to the main branch
2. **Wait for pod to start**: `kubectl get pods -n open-webui -w`
3. **Access the UI**: Navigate to https://open-webui.botocudo.net
4. **Create admin account**: Set up your first admin user account
5. **Verify models**: The Ollama models should be automatically detected from http://10.10.21.6:11434

### Network Configuration

Ensure DNS for `*.botocudo.net` points to Traefik LoadBalancer IP:
- **DNS**: `open-webui.botocudo.net` → `10.10.21.202`
- **Traefik**: Handles TLS termination with Let's Encrypt certificates

## Security Considerations

### WEBUI_SECRET_KEY

The `WEBUI_SECRET_KEY` environment variable in [open-webui.yaml](open-webui.yaml:30-31) is used to encrypt session data and sensitive information. A secure random key has been generated and configured.

To rotate the secret key:
```bash
# Generate new key
openssl rand -hex 32

# Update in open-webui.yaml
kubectl set env deployment/open-webui -n open-webui WEBUI_SECRET_KEY="new-key-here"
```

### Access Control

- First user to register becomes the admin
- Additional users can be created through the UI
- No authentication required for Ollama backend (internal network only)

## Troubleshooting

### Cannot connect to Ollama

Check if the DGX Ollama service is running:
```bash
curl http://10.10.21.6:11434/api/version
```

### No models available

List available models on the DGX:
```bash
curl http://10.10.21.6:11434/api/tags
```

### Check pod logs

```bash
kubectl logs -n open-webui -l app=open-webui -f
```

### Verify connectivity from pod

```bash
kubectl run -it --rm test --image=curlimages/curl --restart=Never -- \
  curl http://10.10.21.6:11434/api/version
```

## Deployment

This app is managed by ArgoCD and will be automatically deployed when changes are pushed to the main branch.

### Manual sync (if needed)

```bash
argocd app sync open-webui
```

### Check deployment status

```bash
kubectl get pods -n open-webui
kubectl get ingress -n open-webui
```

## Related Documentation

- [Open WebUI GitHub](https://github.com/open-webui/open-webui)
- [DGX Ollama Setup](https://github.com/fafiorim/dgx-ollama)
- [Ollama API Reference](https://github.com/ollama/ollama/blob/main/docs/api.md)

## Architecture

```
┌──────────────────────────┐
│   User Browser           │
└────────────┬─────────────┘
             │ HTTPS (443)
             │ open-webui.botocudo.net
             ▼
┌──────────────────────────┐
│  Traefik LoadBalancer    │
│  10.10.21.202            │
│  (TLS w/ Let's Encrypt)  │
└────────────┬─────────────┘
             │ HTTP (8080)
             ▼
┌──────────────────────────┐    HTTP API         ┌──────────────────────────┐
│   Open WebUI Pod         │    10.10.21.6:11434 │  NVIDIA DGX Spark        │
│   Kubernetes Cluster     │◀───────────────────▶│  Ollama Service          │
│                          │                     │                          │
│   OLLAMA_BASE_URL=       │  Model Inference    │  - llama3.2             │
│   http://10.10.21.6:11434│  Requests/Responses │  - mistral              │
│                          │                     │  - CUDA GPU Acceleration │
└────────────┬─────────────┘                     └──────────────────────────┘
             │
             │ NFS Mount
             ▼
┌──────────────────────────┐
│   Synology NAS           │
│   10.10.21.11            │
│   /volume4/VM/containers/│
│   open-webui/data        │
│   (User data, chats)     │
└──────────────────────────┘

Network: All components on 10.10.21.0/24 subnet
```
