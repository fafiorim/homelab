# Open WebUI

Open WebUI is a self-hosted ChatGPT-style web interface for LLMs. This deployment connects to the Ollama instance running on the DGX Spark machine.

## Configuration

### Ollama Backend

- **Ollama Base URL**: `http://10.10.21.6:11434`
- **Available Models**: llama3.2, mistral (and any other models pulled on the DGX)
- **Authentication**: None required
- **GPU**: Models run on NVIDIA DGX Spark GPUs

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

1. ArgoCD will automatically deploy Open WebUI when you push these changes
2. Navigate to https://open-webui.botocudo.net
3. Create your first admin user account
4. The Ollama models should be automatically detected from http://10.10.21.6:11434

## Security Considerations

**Important**: Update the `WEBUI_SECRET_KEY` environment variable in [open-webui.yaml](open-webui.yaml:34) to a secure random string before deploying to production.

Generate a secure key:
```bash
openssl rand -hex 32
```

Then update the environment variable:
```yaml
- name: WEBUI_SECRET_KEY
  value: "your-secure-random-key-here"
```

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
┌─────────────────┐
│   User Browser  │
└────────┬────────┘
         │ HTTPS
         ▼
┌─────────────────┐
│  Traefik (TLS)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐      HTTP      ┌─────────────────┐
│   Open WebUI    │───────────────▶│  DGX Ollama     │
│  (Kubernetes)   │                │  10.10.21.6     │
└────────┬────────┘                └─────────────────┘
         │
         ▼
┌─────────────────┐
│   NFS Storage   │
│  10.10.21.11    │
└─────────────────┘
```
