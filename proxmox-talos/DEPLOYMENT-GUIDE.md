# 🚀 Homelab Deployment Guide

This document explains how to deploy the entire homelab from scratch with full reproducibility.

## 📋 Prerequisites

1. **Talos Kubernetes Cluster** deployed and running
2. **Domain registered in Cloudflare** (botocudo.net)
3. **Cloudflare API Token** with DNS permissions
4. **kubectl** configured to access your cluster

## 🔧 Configuration

### 1. Copy Configuration Template
```bash
cp homelab.conf.template homelab.conf
```

### 2. Edit Configuration
Edit `homelab.conf` with your values:
```bash
# Domain Configuration
export DOMAIN="your-domain.com"
export ADMIN_EMAIL="admin@your-domain.com"

# Cloudflare Configuration
export CLOUDFLARE_API_TOKEN="your_actual_api_token"

# Network Configuration (adjust if needed)
export TRAEFIK_LOADBALANCER_IP="10.10.21.201"
```

## 🚀 Deployment

### Automated Deployment
```bash
./deploy-homelab.sh
```

### Manual Step-by-Step

1. **Deploy MetalLB (LoadBalancer)**
   ```bash
   kubectl apply -f apps/metallb/
   ```

2. **Deploy Traefik (Ingress Controller)**
   ```bash
   kubectl apply -f apps/traefik/
   ```

3. **Apply Ingress Rules**
   ```bash
   kubectl apply -f apps/*/ingress.yaml
   ```

## 🌐 Network Configuration

### Fixed IP Assignment
- **LoadBalancer IP**: `10.10.21.201` (fixed via MetalLB annotation)
- **IP Pool**: `10.10.21.200-10.10.21.210`
- **All services** route through Traefik on ports 80/443

### DNS Requirements
Point these domains to `10.10.21.201`:
```
homepage.botocudo.net    → 10.10.21.201
argocd.botocudo.net      → 10.10.21.201
grafana.botocudo.net     → 10.10.21.201
prometheus.botocudo.net  → 10.10.21.201
npm.botocudo.net         → 10.10.21.201
```

## 🔐 SSL Certificates

### Automatic Let's Encrypt
- **Provider**: Cloudflare DNS-01 Challenge
- **Renewal**: Automatic every 90 days
- **Storage**: Traefik handles certificate storage

### Certificate Details
- **Issuer**: Let's Encrypt (R12)
- **Validity**: 3 months
- **Type**: Real SSL certificates (not self-signed)

## 📁 File Structure

### Configuration Files
```
proxmox-talos/
├── homelab.conf.template     # Template configuration
├── homelab.conf              # Your actual config (gitignored)
├── deploy-homelab.sh         # Automated deployment script
└── apps/
    ├── metallb/              # LoadBalancer configuration
    ├── traefik/              # Ingress controller + SSL
    │   ├── config.yaml       # Traefik configuration
    │   ├── deployment.yaml   # Traefik pods + service
    │   └── cloudflare-secret.yaml  # API token (generated)
    ├── homepage/ingress.yaml # Homepage routing
    ├── monitoring/ingress.yaml # Grafana + Prometheus
    └── ...
```

## 🔄 Reproducible Deployment

### What's Guaranteed
✅ **LoadBalancer IP**: Always `10.10.21.201` (MetalLB annotation)  
✅ **Service Ports**: Always 80/443 (Traefik handles routing)  
✅ **SSL Certificates**: Automatic Let's Encrypt renewal  
✅ **Configuration**: Template-based deployment  

### What to Update
- Update `homelab.conf` with your domain/token
- Update DNS records to point to LoadBalancer IP
- Adjust MetalLB IP range if network conflicts

## 🧪 Testing Deployment

```bash
# Test HTTPS endpoints
curl -k https://homepage.botocudo.net
curl -k https://argocd.botocudo.net
curl -k https://grafana.botocudo.net

# Check certificates
echo | openssl s_client -servername homepage.botocudo.net -connect homepage.botocudo.net:443 2>/dev/null | openssl x509 -noout -dates

# Check Traefik routes
curl -s http://10.10.21.201:8080/api/http/routers
```

## 🔒 Security Notes

1. **homelab.conf** contains sensitive data (API token) - excluded from git
2. **cloudflare-secret.yaml** is generated automatically - excluded from git
3. **SSL certificates** are stored securely in Kubernetes secrets
4. **API token** has minimal required permissions (DNS:Edit, Zone:Read)

## 🆘 Troubleshooting

### Certificate Issues
```bash
# Check Traefik logs
kubectl logs -n traefik-system -l app=traefik

# Check certificate secrets
kubectl get secrets -A | grep tls
```

### LoadBalancer Issues
```bash
# Check MetalLB status
kubectl get pods -n metallb-system

# Check IP assignment
kubectl get svc traefik -n traefik-system
```