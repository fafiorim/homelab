# Secrets Management

This document describes how Kubernetes secrets are managed for this homelab.

## Overview

Kubernetes secrets contain sensitive data like encryption keys, API tokens, and passwords. These **should NOT** be committed to git repositories.

## Secret Backup Location

Secrets are backed up locally on your machine (not in git):

```
~/.kube/secrets/homelab/
├── n8n-secrets.yaml          # n8n encryption key
└── (future secrets here)
```

### Directory Permissions

```bash
# Directory: owner read/write/execute only
chmod 700 ~/.kube/secrets/homelab

# Files: owner read/write only
chmod 600 ~/.kube/secrets/homelab/*.yaml
```

## Current Secrets

### n8n-secrets

**Namespace**: `n8n`
**Backup**: `~/.kube/secrets/homelab/n8n-secrets.yaml`
**Contains**: `encryption-key` - Used by n8n to encrypt sensitive workflow data

**To restore:**
```bash
kubectl apply -f ~/.kube/secrets/homelab/n8n-secrets.yaml
```

**To recreate (will invalidate existing n8n data):**
```bash
kubectl create secret generic n8n-secrets -n n8n \
  --from-literal=encryption-key="$(openssl rand -hex 32)"

# Backup the new secret
kubectl get secret n8n-secrets -n n8n -o yaml > ~/.kube/secrets/homelab/n8n-secrets.yaml
```

## Adding New Secrets

When creating new secrets:

1. **Create the secret in Kubernetes:**
   ```bash
   kubectl create secret generic my-secret -n my-namespace \
     --from-literal=key=value
   ```

2. **Backup locally (NOT in git):**
   ```bash
   kubectl get secret my-secret -n my-namespace -o yaml \
     > ~/.kube/secrets/homelab/my-secret.yaml
   chmod 600 ~/.kube/secrets/homelab/my-secret.yaml
   ```

3. **Document it here** in this SECRETS.md file

4. **DO NOT** commit the secret yaml to git

## Alternative: Sealed Secrets (Future)

For a more git-friendly approach, consider using [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets):

```bash
# Install sealed-secrets controller (one time)
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Encrypt a secret (can be committed to git)
kubeseal -f ~/.kube/secrets/homelab/n8n-secrets.yaml \
  -w proxmox-talos/apps/n8n/n8n-sealed-secret.yaml

# The sealed secret can be committed to git safely
git add proxmox-talos/apps/n8n/n8n-sealed-secret.yaml
```

## Secret Recovery

If you need to restore all secrets to a fresh cluster:

```bash
# Restore all secrets
for secret in ~/.kube/secrets/homelab/*.yaml; do
  kubectl apply -f "$secret"
done
```

## Security Best Practices

1. ✅ **DO**: Keep secrets in `~/.kube/secrets/homelab/`
2. ✅ **DO**: Backup secrets to encrypted external storage (USB, cloud backup)
3. ✅ **DO**: Use strong, randomly generated values (`openssl rand -hex 32`)
4. ✅ **DO**: Limit file permissions (`chmod 600`)
5. ❌ **DO NOT**: Commit secrets to git
6. ❌ **DO NOT**: Share secrets in plain text
7. ❌ **DO NOT**: Store secrets in cluster without backups

## Additional Backup Recommendations

1. **Encrypt and backup to cloud:**
   ```bash
   tar czf - ~/.kube/secrets/homelab | \
     gpg -e -r your@email.com > homelab-secrets-backup.tar.gz.gpg
   # Upload to Google Drive, Dropbox, etc.
   ```

2. **Store in password manager:**
   - Extract secret values and store in 1Password, Bitwarden, etc.
   ```bash
   kubectl get secret n8n-secrets -n n8n -o jsonpath='{.data.encryption-key}' | base64 -d
   ```

3. **Version control secrets separately:**
   - Use a private git repo with git-crypt or git-secret
   - Keep it separate from your main homelab repo
