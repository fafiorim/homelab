# Proxmox Talos Kubernetes Cluster

A streamlined automation solution for deploying a Talos Kubernetes cluster on Proxmox infrastructure with a single command.

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
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Proxmox details
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

### 4. Cleanup

```bash
./talos-cluster.sh cleanup
```

## Main Script: `talos-cluster.sh`

This is the **single entry point** for all cluster operations:

### Commands

| Command | Description | Options |
|---------|-------------|---------|
| `deploy` | Deploy complete Talos Kubernetes cluster | `--force`, `--verbose`, `--dry-run` |
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

Edit `terraform.tfvars` to configure:

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

MAC addresses are configurable through the `terraform.tfvars` file:

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
├── terraform.tfvars            # Configuration file
├── terraform.tfvars.example    # Example configuration
├── talos-configs/              # Generated Talos configs
├── kubeconfig                  # Kubernetes config
├── main.tf                     # Terraform configuration
├── variables.tf                # Terraform variables
└── outputs.tf                  # Terraform outputs
```

## Error Handling

- **Existing VMs**: By default, the script will error if VMs with the same IDs exist
- **Force Mode**: Use `--force` to automatically delete existing VMs and continue
- **Prerequisites**: Script checks for required tools (talosctl, kubectl, curl, jq)
- **Configuration**: Validates terraform.tfvars file exists and is properly configured

## Troubleshooting

### Common Issues

1. **VM Creation Fails**
   - Check Proxmox API credentials
   - Verify storage pool exists
   - Ensure Talos ISO is uploaded

2. **VM Conflict Errors**
   - Use `--force` to delete existing VMs
   - Or manually delete VMs via Proxmox web interface
   - Or use different VM IDs in terraform.tfvars

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

- Keep `terraform.tfvars` secure
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

## Support

For issues and questions:
- Check the troubleshooting section
- Review Talos documentation: https://www.talos.dev/docs/
- Open an issue on GitHub