# OpenClaw — Personal AI Assistant

[OpenClaw](https://github.com/openclaw/openclaw) is a personal AI assistant you run on your own infrastructure. It provides a Gateway (control plane) and can connect to WhatsApp, Telegram, Slack, Discord, Google Chat, Signal, iMessage, and more.

- **Docs:** [openclaw.ai](https://openclaw.ai) · [GitHub](https://github.com/openclaw/openclaw)
- **URL:** https://openclaw.botocudo.net

## Deployment

ArgoCD syncs OpenClaw from Git (app-of-apps). Ensure the bootstrap Application is applied, then OpenClaw is created and synced automatically.

### Prerequisites

1. **NFS directory** (same pattern as n8n/paperless). On the NFS server (10.10.21.11):
   ```bash
   mkdir -p /volume4/VM/containers/openclaw/data
   chmod -R 777 /volume4/VM/containers/openclaw
   ```

2. **Secret** (not in Git). Create before or after first sync so the gateway can require auth:
   ```bash
   kubectl create namespace openclaw
   # Option A: token auth (recommended)
   kubectl create secret generic openclaw-secrets -n openclaw \
     --from-literal=gateway-token="$(openssl rand -hex 24)"
   # Option B: password auth (set gateway-password instead; see OpenClaw docs)
   # kubectl create secret generic openclaw-secrets -n openclaw \
   #   --from-literal=gateway-password="your-secure-password"
   ```

3. **DNS:** Point `openclaw.botocudo.net` to your Traefik LoadBalancer.

### Image

The manifest uses `ghcr.io/openclaw/openclaw:latest`. If that image is not published, build and push from [openclaw/openclaw](https://github.com/openclaw/openclaw):

```bash
git clone https://github.com/openclaw/openclaw.git && cd openclaw
docker build -t your-registry/openclaw:latest .
docker push your-registry/openclaw:latest
# Then set spec.template.spec.containers[0].image in deployment.yaml
```

## After deploy

1. Open https://openclaw.botocudo.net — you should see the Control UI (or WebChat). Use the token or password from the secret to authenticate if configured.
2. Run the **onboarding wizard** from your machine (with gateway URL pointing at your instance) to configure channels and models:
   ```bash
   npm install -g openclaw@latest
   openclaw onboard
   ```
   Use gateway URL `wss://openclaw.botocudo.net` (or `https://openclaw.botocudo.net`) and the token/password you set in the secret.

## Persistence

- **PV/PVC:** NFS at `/volume4/VM/containers/openclaw/data` (5Gi), mounted at `/home/node/.openclaw` (config + workspace).
- Data survives pod restarts.

## Troubleshooting

- **ImagePullBackOff:** The image `ghcr.io/openclaw/openclaw:latest` may not exist. Build from source and push to your registry, then update the deployment image.
- **CreateContainerConfigError:** Create the `openclaw-secrets` secret (see above). If you use only password, remove the `gateway-token` reference from the deployment or make the secret have both keys.
- **Pod not ready:** Ensure the NFS path exists and the PVC is bound. Check logs: `kubectl logs -n openclaw -l app=openclaw -f`.
