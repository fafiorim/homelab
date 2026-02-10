# Chat Hub

A lightweight, multi-provider AI chat interface for your homelab.

## Overview

Chat Hub is a simple web-based chat interface that supports multiple LLM providers:
- **Local LLMs** via Ollama
- **OpenAI** (ChatGPT models)
- **Anthropic** (Claude models)
- **Google** (Gemini models)
- **Azure OpenAI**
- **Custom OpenAI-compatible endpoints**

Built on [ChatGPT-Next-Web](https://github.com/ChatGPTNextWeb/ChatGPT-Next-Web), it provides a clean, responsive interface for interacting with various AI models from a single application.

## Features

- Multi-provider support (local and cloud)
- Model selection per conversation
- Custom endpoint configuration
- Persistent chat history
- Mobile-responsive design
- No account required (optional access code)

## Access

- **URL**: https://chat-hub.botocudo.net
- **Namespace**: `chat-hub`

## Configuration

The deployment is configured via environment variables in [chat-hub.yaml](./chat-hub.yaml):

### API Keys

To use cloud providers, update the environment variables:

```yaml
env:
  - name: OPENAI_API_KEY
    value: "sk-your-openai-key"
  - name: ANTHROPIC_API_KEY
    value: "sk-ant-your-anthropic-key"
  - name: GOOGLE_API_KEY
    value: "your-google-key"
```

### Ollama Integration

To use local Ollama models, set the base URL:

```yaml
env:
  - name: OPENAI_API_KEY
    value: "sk-placeholder"
  - name: BASE_URL
    value: "http://10.10.21.6:11434/v1"  # Your Ollama server
  - name: CUSTOM_MODELS
    value: "+llama3.2,+qwen2.5,+mistral"
```

### Access Control

To require an access code:

```yaml
env:
  - name: CODE
    value: "your-secret-code"
```

Leave empty for open access.

## Storage

- **PV**: 5Gi NFS volume
- **Path**: `/volume4/VM/containers/chat-hub/data`
- **Server**: 10.10.21.11

Chat history and settings are persisted to NFS storage.

## Deployment

This app is managed by ArgoCD and will auto-sync from Git.

### Manual Deployment

```bash
# Apply via kubectl
kubectl apply -k .

# Or sync via ArgoCD
kubectl annotate application chat-hub -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

### Check Status

```bash
# Check pods
kubectl get pods -n chat-hub

# Check logs
kubectl logs -n chat-hub deployment/chat-hub

# Check ingress
kubectl get ingress -n chat-hub
```

## Usage Examples

### Using with Local Ollama

1. Set `BASE_URL` to your Ollama endpoint
2. Add your models to `CUSTOM_MODELS`
3. In the UI, select your model from the dropdown
4. Start chatting

### Using with OpenAI

1. Set `OPENAI_API_KEY` in the deployment
2. Set `BASE_URL` to `https://api.openai.com`
3. Select GPT models from the UI
4. Start chatting

### Using with Anthropic Claude

1. Set `ANTHROPIC_API_KEY` in the deployment
2. The app will automatically detect Claude models
3. Select Claude models from the UI
4. Start chatting

## Troubleshooting

### Pod not starting

Check if the NFS directory exists:
```bash
ssh admin@10.10.21.11
ls -la /volume4/VM/containers/chat-hub/
```

Create if missing:
```bash
mkdir -p /volume4/VM/containers/chat-hub/data
chmod 777 /volume4/VM/containers/chat-hub/data
```

### API Key not working

Verify the key is set correctly:
```bash
kubectl get deployment chat-hub -n chat-hub -o yaml | grep -A 5 "env:"
```

### TLS Certificate Issues

Check certificate status:
```bash
kubectl get certificate -n chat-hub
kubectl describe certificate chat-hub-botocudo-net-tls -n chat-hub
```

## Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `OPENAI_API_KEY` | OpenAI API key | `sk-...` |
| `ANTHROPIC_API_KEY` | Anthropic API key | `sk-ant-...` |
| `GOOGLE_API_KEY` | Google API key | `AIza...` |
| `BASE_URL` | API endpoint URL | `https://api.openai.com` |
| `CUSTOM_MODELS` | Custom model list | `+llama3.2,+qwen2.5` |
| `CODE` | Access password | `secret123` |
| `HIDE_USER_API_KEY` | Hide API key input | `false` |
| `DISABLE_GPT4` | Disable GPT-4 models | `false` |

## Links

- [ChatGPT-Next-Web Documentation](https://github.com/ChatGPTNextWeb/ChatGPT-Next-Web)
- [Ollama Documentation](https://ollama.ai/docs)
- [OpenAI API Documentation](https://platform.openai.com/docs)
- [Anthropic API Documentation](https://docs.anthropic.com)
