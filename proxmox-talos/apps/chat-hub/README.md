# Chat Hub

A lightweight, custom-built multi-provider AI chat interface for your homelab.

## Overview

Chat Hub is a simple web-based chat interface that supports multiple LLM providers:
- **Local LLMs** via Ollama
- **OpenAI** (ChatGPT models)
- **Anthropic** (Claude models)

Built with Node.js/Express backend and vanilla JavaScript frontend, inspired by the [FinGuard](https://github.com/fafiorim/finguard) design pattern.

## Features

- Multi-provider support (local and cloud)
- Model selection per conversation
- Custom endpoint configuration
- Client-side configuration (stored in browser localStorage)
- Clean, responsive interface
- No authentication required
- Minimal resource footprint

## Access

- **URL**: https://chat-hub.botocudo.net
- **Namespace**: `chat-hub`

## Application Structure

```
app/
├── server.js           # Express backend with API proxy
├── package.json        # Node.js dependencies
├── Dockerfile          # Container image definition
├── build.sh            # Build script
└── public/
    ├── index.html      # Main chat interface
    ├── styles.css      # Styling
    └── script.js       # Frontend logic
```

## Building the Container Image

The app is containerized using Docker. To build and deploy:

```bash
cd app/

# Build the image (customize registry/tag as needed)
./build.sh ghcr.io/fafiorim/chat-hub:latest

# Push to registry
docker push ghcr.io/fafiorim/chat-hub:latest

# Update the image in chat-hub.yaml if using a different tag
```

## Configuration

All configuration is done through the web UI - no Kubernetes configuration needed!

1. **Select Provider**: Choose between Ollama, OpenAI, or Anthropic
2. **Set Endpoint**: API endpoint URL (auto-filled based on provider)
3. **API Key**: Required for OpenAI and Anthropic (optional for Ollama)
4. **Select Model**: Auto-loaded from the provider

Configuration is saved to browser localStorage and persists across sessions.

### Default Ollama Configuration

```
Provider: Ollama
Endpoint: http://10.10.21.6:11434
API Key: (not required)
```

## Storage

- **PV**: 5Gi NFS volume
- **Path**: `/volume4/VM/containers/chat-hub/data`
- **Server**: 10.10.21.11

Used for persistent data (future enhancement).

## Deployment

This app is managed by ArgoCD and will auto-sync from Git.

### Create NFS Directory

Before deploying, create the NFS directory:

```bash
ssh admin@10.10.21.11
mkdir -p /volume4/VM/containers/chat-hub/data
chmod 777 /volume4/VM/containers/chat-hub/data
```

### Deploy via ArgoCD

```bash
# The app is already registered via bootstrap
# Force sync to deploy
kubectl annotate application chat-hub -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

### Check Status

```bash
# Check pods
kubectl get pods -n chat-hub

# Check logs
kubectl logs -n chat-hub deployment/chat-hub -f

# Check ingress
kubectl get ingress -n chat-hub
```

## Usage

1. Open https://chat-hub.botocudo.net
2. Configure your provider in the left sidebar
3. Select a model
4. Start chatting!

### Using with Local Ollama

1. Select "Ollama (Local)" as provider
2. Endpoint auto-fills to `http://10.10.21.6:11434`
3. Click "Refresh Models" to load available models
4. Select a model and start chatting

### Using with OpenAI

1. Select "OpenAI" as provider
2. Enter your OpenAI API key
3. Click "Refresh Models" to load GPT models
4. Select a model and start chatting

### Using with Anthropic Claude

1. Select "Anthropic (Claude)" as provider
2. Enter your Anthropic API key
3. Select a Claude model from the dropdown
4. Start chatting

## Troubleshooting

### Pod not starting

Check pod status and logs:
```bash
kubectl describe pod -n chat-hub -l app=chat-hub
kubectl logs -n chat-hub -l app=chat-hub --tail=50
```

### NFS directory issues

Verify NFS directory exists:
```bash
ssh admin@10.10.21.11
ls -la /volume4/VM/containers/chat-hub/data
```

### Image pull errors

Ensure the image is pushed to the registry:
```bash
docker push ghcr.io/fafiorim/chat-hub:latest
```

### API errors

Check the browser console (F12) for detailed error messages. Common issues:
- Invalid API key
- Incorrect endpoint URL
- Model not available

### TLS Certificate Issues

Check certificate status:
```bash
kubectl get ingress -n chat-hub
kubectl describe ingress chat-hub-ingress -n chat-hub
```

Wait 1-2 minutes for Let's Encrypt certificate issuance.

## Development

To run locally for development:

```bash
cd app/

# Install dependencies
npm install

# Start server
npm start

# Access at http://localhost:3000
```

## Technology Stack

- **Backend**: Node.js 18 + Express
- **Frontend**: Vanilla JavaScript, HTML5, CSS3
- **Container**: Docker (Alpine-based)
- **Orchestration**: Kubernetes + ArgoCD
- **Ingress**: Traefik with Let's Encrypt
- **Storage**: NFS persistent volumes

## Links

- [FinGuard](https://github.com/fafiorim/finguard) - Design inspiration
- [Ollama Documentation](https://ollama.ai/docs)
- [OpenAI API Documentation](https://platform.openai.com/docs)
- [Anthropic API Documentation](https://docs.anthropic.com)
