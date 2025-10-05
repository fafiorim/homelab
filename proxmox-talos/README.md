# 🏠 Homelab Modular Deployment System

A comprehensive, modular deployment system for a complete homelab infrastructure running on Proxmox with Talos Kubernetes.

## 🏗️ Architecture Overview

This system deploys a complete homelab infrastructure using a modular approach that allows for:
- **Independent module deployment** - Run individual components separately
- **Full stack deployment** - Deploy everything with a single command
- **Easy troubleshooting** - Isolated modules for targeted debugging
- **Future extensibility** - Add new modules without affecting existing ones

## 📦 Modules

### 1. Infrastructure (`01-infrastructure.sh`)
- **Purpose**: Proxmox VM deployment and Talos Kubernetes cluster setup
- **Features**:
  - Creates 3 Proxmox VMs (1 control plane, 2 workers)
  - Configures VMs with qemu-agent support for Proxmox integration
  - Generates Talos configuration with network patches
  - Bootstraps Kubernetes cluster
  - Retrieves and validates kubeconfig

### 2. MetalLB (`02-metallb.sh`)
- **Purpose**: LoadBalancer service for bare-metal Kubernetes
- **Features**:
  - Installs MetalLB controller
  - Configures IP address pool (10.10.21.200-10.10.21.210)
  - Sets up L2 advertisement
  - Validates LoadBalancer functionality

### 3. Traefik (`03-traefik.sh`)
- **Purpose**: Ingress controller with automatic SSL certificates
- **Features**:
  - Deploys Traefik v3.1 with LoadBalancer service
  - Configures Let's Encrypt SSL via Cloudflare DNS-01 challenge
  - Sets up automatic certificate renewal
  - Provides ingress routing for all services

### 4. ArgoCD (`04-argocd.sh`)
- **Purpose**: GitOps continuous deployment controller
- **Features**:
  - Installs ArgoCD via Helm charts
  - Configures ingress with SSL termination
  - Retrieves admin credentials
  - Sets up HTTPS access

### 5. Applications (`05-applications.sh`)
- **Purpose**: Application deployment orchestration via ArgoCD
- **Features**:
  - Auto-discovers applications in `apps/` directory
  - Deploys applications via ArgoCD
  - Monitors application health and sync status
  - Verifies service accessibility

## 🚀 Quick Start

### Prerequisites
- Proxmox VE server with API access
- Required tools: `curl`, `jq`, `kubectl`, `talosctl`, `helm`
- Configuration files: `config.conf`, `cluster.conf`
- Cloudflare API token with DNS permissions

### Full Deployment
```bash
# Deploy complete homelab infrastructure
./deploy-homelab.sh --full
```

### Individual Module Deployment
```bash
# Deploy only infrastructure
./deploy-homelab.sh 01-infrastructure

# Deploy only Traefik
./deploy-homelab.sh 03-traefik
```

### Management Commands
```bash
# Check prerequisites
./deploy-homelab.sh --check

# Show deployment status
./deploy-homelab.sh --status

# Verify all services
./deploy-homelab.sh --verify

# List available modules
./deploy-homelab.sh --list
```

## 📁 Directory Structure

```
homelab/
├── deploy-homelab.sh           # Master orchestrator script
├── config.conf                 # Main configuration file
├── cluster.conf                # Talos cluster configuration
├── modules/                    # Individual deployment modules
│   ├── 01-infrastructure.sh
│   ├── 02-metallb.sh
│   ├── 03-traefik.sh
│   ├── 04-argocd.sh
│   └── 05-applications.sh
├── apps/                       # ArgoCD application manifests
│   ├── homepage/
│   ├── grafana/
│   ├── prometheus/
│   └── metrics-server/
└── manifests/                  # Kubernetes manifests
    ├── metallb/
    ├── traefik/
    └── argocd/
```

## ⚙️ Configuration

### Main Configuration (`config.conf`)
```bash
# Domain configuration
DOMAIN="botocudo.net"

# Cloudflare API
CLOUDFLARE_API_TOKEN="your-token-here"
CLOUDFLARE_EMAIL="your-email@domain.com"

# MetalLB IP pool
METALLB_IP_RANGE="10.10.21.200-10.10.21.210"
LOADBALANCER_IP="10.10.21.201"
```

### Cluster Configuration (`cluster.conf`)
```bash
# Proxmox configuration
PROXMOX_HOST="10.10.20.100"
PROXMOX_USER="root@pam"
PROXMOX_PASSWORD="your-password"

# VM configuration
CONTROL_PLANE_VM_ID=400
WORKER_VM_IDS=(411 412)
```

## 🔧 Features

### Error Handling
- Comprehensive error checking at each step
- Prerequisite validation before deployment
- Graceful failure handling with rollback options
- Detailed logging and status reporting

### Security
- Secrets management with `.gitignore` protection
- SSL/TLS encryption for all services
- Automatic certificate renewal
- Secure credential storage

### Monitoring
- Real-time deployment status
- Service health checks
- Application sync monitoring
- URL accessibility verification

### Extensibility
- Modular architecture for easy expansion
- Template-based module creation
- Standardized logging and error handling
- Configuration-driven deployment

## 🌐 Deployed Services

After successful deployment, the following services will be available:

- **🏠 Homepage**: `https://homepage.botocudo.net` - Dashboard and service overview
- **📊 Grafana**: `https://grafana.botocudo.net` - Monitoring and visualization
- **📈 Prometheus**: `https://prometheus.botocudo.net` - Metrics collection
- **🔧 ArgoCD**: `https://argocd.botocudo.net` - GitOps management

All services are secured with valid Let's Encrypt SSL certificates and accessible via HTTPS.

## 🔍 Troubleshooting

### Check Prerequisites
```bash
./deploy-homelab.sh --check
```

### View Deployment Status
```bash
./deploy-homelab.sh --status
```

### Test Service Connectivity
```bash
./deploy-homelab.sh --verify
```

### Individual Module Testing
```bash
# Test specific module
./deploy-homelab.sh 02-metallb
```

### Manual Verification
```bash
# Check cluster connectivity
export KUBECONFIG=./kubeconfig
kubectl get nodes

# Check service status
kubectl get pods --all-namespaces

# Check LoadBalancer IP
kubectl get svc traefik -n traefik-system
```

## 🧹 Cleanup

⚠️ **WARNING**: This will destroy ALL resources!

```bash
./deploy-homelab.sh --cleanup
```

## 📝 Logs and Credentials

- **ArgoCD Admin Password**: Stored in `.argocd-admin-password`
- **Service Credentials**: Stored in `service-credentials.txt`
- **Deployment Logs**: Displayed in real-time during execution

## 🤝 Contributing

To add a new module:

1. Create `modules/XX-newmodule.sh` following the existing pattern
2. Add module to `MODULES` array in `deploy-homelab.sh`
3. Add description to `MODULE_DESCRIPTIONS` array
4. Test with `./deploy-homelab.sh XX-newmodule`

## 📄 License

This project is part of a personal homelab setup. Use at your own risk and ensure you understand the security implications of the deployed services.

## Overview

This project provides the **easiest way** to:
- Create 3 Proxmox VMs (1 control plane + 2 workers)
- Install and configure Talos Linux
- Bootstrap a fully functional Kubernetes cluster
- Manage the entire lifecycle with one script

## Quick Start

### Prerequisites

- Proxmox VE server with API access
- `talosctl` and `kubectl` installed locally
- Network access to Proxmox API
- Talos ISO uploaded to Proxmox storage

### 1. Configuration

Copy and edit the configuration file:

```bash
cp config.conf.example config.conf
# Edit config.conf with your Proxmox details
```

### 2. Deploy Cluster

```bash
# Deploy complete cluster (will error if VMs exist)
./talos-cluster.sh deploy

# Deploy with force delete existing VMs
./talos-cluster.sh deploy --force
```

### 3. Check Status

```bash
./talos-cluster.sh status
```

### 4. Install ArgoCD (GitOps)

```bash
./talos-cluster.sh argocd
```

### 5. Deploy Applications

```bash
./talos-cluster.sh apps
```

**Note**: Applications will sync from the Git repository configured in `config.conf`. By default, this is set to `https://github.com/fafiorim/homelab`. You can change this by editing `config.conf` or using the helper script:

```bash
./update-git-repo.sh
```

#### Available Applications

- **Homepage**: Dashboard application for service overview
- **Monitoring**: Complete monitoring stack with Prometheus, Grafana, and Node Exporter
- **Test Applications**: Simple applications for testing cluster functionality

#### Monitoring Stack Access

After deploying applications, you can access:
- **Grafana Dashboard**: `http://<any-node-ip>:30000`
  - Default credentials: `admin` / `admin123`
  - Pre-configured with Prometheus datasource
- **Prometheus**: Internal access at `http://prometheus.monitoring.svc.cluster.local:9090`

Example: `http://10.10.21.110:30000` (using control plane IP)

### 6. Cleanup

```bash
./talos-cluster.sh cleanup
```

## Main Script: `talos-cluster.sh`

This is the **single entry point** for all cluster operations:

### Commands

| Command | Description | Options |
|---------|-------------|---------|
| `deploy` | Deploy complete Talos Kubernetes cluster | `--force`, `--verbose`, `--dry-run` |
| `argocd` | Install ArgoCD for GitOps | `--verbose` |
| `apps` | Deploy applications via ArgoCD | `--verbose` |
| `argocd-info` | Show ArgoCD access information | `--verbose` |
| `cleanup` | Remove all VMs and configurations | `--verbose` |
| `status` | Show cluster and VM status | `--verbose` |
| `help` | Show help message | |

### Options

- `--force`: Force delete existing VMs with same IDs before deploying
- `--verbose`: Enable verbose output for debugging
- `--dry-run`: Show what would be done without executing

### Examples

```bash
# Deploy cluster (safe mode - errors if VMs exist)
./talos-cluster.sh deploy

# Deploy cluster with force delete existing VMs
./talos-cluster.sh deploy --force

# Check current status
./talos-cluster.sh status

# Remove everything
./talos-cluster.sh cleanup

# Get help
./talos-cluster.sh help
```

## Configuration

Edit `config.conf` to configure your Proxmox and cluster settings.

### Git Repository Configuration

The GitOps setup uses a configurable Git repository for application deployment. You can change the repository by:

1. **Edit `config.conf`**:
   ```bash
   # GitOps Configuration
   git_repo_url = "https://github.com/your-username/your-repo"
   git_repo_branch = "main"
   ```

2. **Use the helper script**:
   ```bash
   ./update-git-repo.sh
   ```

3. **Redeploy applications**:
   ```bash
   ./talos-cluster.sh apps
   ```

### Proxmox Configuration

Edit `config.conf` to configure:

```hcl
# Proxmox Configuration
proxmox_api_url           = "https://your-proxmox:8006/api2/json"
proxmox_api_token_id      = "your-token-id"
proxmox_api_token_secret  = "your-token-secret"
proxmox_node              = "your-node-name"

# Storage and Network
storage_pool   = "local-lvm"
network_bridge = "vmbr0"
iso_storage    = "local"

# Cluster Configuration
cluster_name        = "your-cluster"
control_plane_ip    = "10.10.21.110"
worker_node_01_ip   = "10.10.21.111"
worker_node_02_ip   = "10.10.21.112"

# MAC Address Configuration
# Format: xx:xx:xx:xx:xx:xx or xx-xx-xx-xx-xx-xx
# These MAC addresses should be unique within your network
control_plane_mac   = "bc:24:11:82:9f:fb"
worker_01_mac       = "bc:24:11:51:6f:4d"
worker_02_mac       = "bc:24:11:82:9f:3c"

# Talos ISO
talos_iso = "talos-v1.11.1-amd64.iso"
```

## VM Management

The script manages 3 VMs by default:
- **Control Plane**: VM ID 400 (talos-control-plane)
- **Worker 01**: VM ID 411 (talos-worker-01)  
- **Worker 02**: VM ID 412 (talos-worker-02)

### MAC Address Configuration

MAC addresses are configurable through the `config.conf` file:

| VM | Variable | Default MAC | Purpose |
|----|----------|-------------|---------|
| Control Plane | `control_plane_mac` | `bc:24:11:82:9f:fb` | Control plane VM network interface |
| Worker 01 | `worker_01_mac` | `bc:24:11:51:6f:4d` | First worker VM network interface |
| Worker 02 | `worker_02_mac` | `bc:24:11:82:9f:3c` | Second worker VM network interface |

**Important Notes:**
- MAC addresses must be unique within your network
- Format: `xx:xx:xx:xx:xx:xx` or `xx-xx-xx-xx-xx-xx`
- The system validates MAC address format automatically
- Changing MAC addresses requires VM recreation

## Cluster Information

After deployment, you'll have:

- **Control Plane**: VM ID 400 (10.10.21.110)
- **Worker 01**: VM ID 411 (10.10.21.111)  
- **Worker 02**: VM ID 412 (10.10.21.112)

### Access Points

- **Kubernetes API**: `https://10.10.21.110:6443`
- **Kubeconfig**: `./kubeconfig`
- **Talos Config**: `./talos-configs/talosconfig`

## File Structure

```
├── talos-cluster.sh            # Main management script
├── deploy_talos_cluster.sh     # Core deployment logic
├── install-argocd.sh           # ArgoCD installation script
├── deploy-apps.sh              # Application deployment script
├── setup-env.sh                # Environment setup script
├── config.conf                 # Configuration file
├── config.conf.example         # Example configuration
├── talos-configs/              # Generated Talos configs
├── kubeconfig                  # Kubernetes config
├── manifests/                  # Kubernetes manifests
│   └── argocd/                 # ArgoCD installation files
├── apps/                       # ArgoCD Applications (GitOps)
│   ├── homepage/               # Homepage dashboard
│   ├── monitoring/             # Monitoring stack (Prometheus + Grafana)
│   ├── simple-test/            # Simple test applications
│   └── test-app/               # Test applications
└── ENHANCED-FEATURES.md        # Documentation of enhancements
```

## Error Handling

- **Existing VMs**: By default, the script will error if VMs with the same IDs exist
- **Force Mode**: Use `--force` to automatically delete existing VMs and continue
- **Prerequisites**: Script checks for required tools (talosctl, kubectl, curl, jq)
- **Configuration**: Validates config.conf file exists and is properly configured

## Troubleshooting

### Common Issues

1. **VM Creation Fails**
   - Check Proxmox API credentials
   - Verify storage pool exists
   - Ensure Talos ISO is uploaded

2. **VM Conflict Errors**
   - Use `--force` to delete existing VMs
   - Or manually delete VMs via Proxmox web interface
   - Or use different VM IDs in config.conf

3. **Talos Configuration Fails**
   - Check network connectivity
   - Verify IP addresses are correct
   - Ensure VMs are running

4. **Cluster Bootstrap Fails**
   - Check control plane VM status
   - Verify network configuration
   - Check Talos logs

### Logs and Debugging

```bash
# Check cluster status
./talos-cluster.sh status

# Deploy with verbose output
./talos-cluster.sh deploy --force --verbose

# Check what would be done
./talos-cluster.sh deploy --dry-run
```

## Security

- Keep `config.conf` secure
- Don't commit secrets to version control
- Use proper RBAC for production deployments
- Regularly update Talos and Kubernetes

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Documentation

- **README.md** - Main documentation and quick start guide
- **ENHANCED-FEATURES.md** - Detailed feature documentation and improvements
- **MONITORING.md** - Comprehensive monitoring stack documentation
- **config.conf.example** - Configuration template with examples

## Security Considerations

### Secrets Management

**⚠️ IMPORTANT**: The `config.conf` file contains sensitive information including API tokens and credentials.

1. **Never commit secrets to version control**:
   ```bash
   # Add config.conf to .gitignore
   echo "config.conf" >> .gitignore
   ```

2. **Use config.conf.example as template**:
   ```bash
   cp config.conf.example config.conf
   # Edit config.conf with your actual values
   ```

3. **Required secrets to configure**:
   - `proxmox_api_token_secret`: Your Proxmox API token
   - `CLOUDFLARE_API_TOKEN`: Your Cloudflare API token for SSL certificates

4. **File permissions**:
   ```bash
   chmod 600 config.conf  # Make readable only by owner
   ```

### Production Recommendations

- Use dedicated service accounts with minimal required permissions
- Rotate API tokens regularly
- Consider using HashiCorp Vault or similar for secret management in production
- Enable audit logging on Proxmox for API access monitoring

## Support

For issues and questions:
- Check the troubleshooting section
- Review Talos documentation: https://www.talos.dev/docs/
- Review monitoring documentation: `MONITORING.md`
- Open an issue on GitHub