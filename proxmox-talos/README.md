# Talos Kubernetes Cluster on Proxmox

This project deploys a 3-node Talos Kubernetes cluster on Proxmox VE using direct API calls (bypassing Terraform provider issues).

## Architecture

- **Control Plane**: 1 node (4 cores, 6GB RAM, 50GB disk)
- **Worker Nodes**: 2 nodes (4 cores, 6GB RAM, 50GB disk each)

## VM Configuration

| Node | VM ID | IP Address | MAC Address | Role | Specs |
|------|-------|------------|-------------|------|-------|
| talos-control-plane | 400 | 10.10.21.110 | bc:24:11:82:9f:fb | Control Plane | 4 cores, 6GB RAM, 50GB disk |
| talos-worker-01 | 411 | 10.10.21.111 | bc:24:11:51:6f:4d | Worker | 4 cores, 6GB RAM, 50GB disk |
| talos-worker-02 | 412 | 10.10.21.112 | bc:24:11:82:9f:3c | Worker | 4 cores, 6GB RAM, 50GB disk |

## Prerequisites

1. **Proxmox VE** with API access configured
2. **Talos ISO** uploaded to Proxmox storage (`talos-v1.11.1-amd64.iso`)
3. **Network bridge** configured (default: vmbr0)
4. **Storage pool** available (default: local-lvm)
5. **API Token** with sufficient permissions

## Proxmox Setup

### 1. Create API Token

1. Go to **Datacenter** → **Permissions** → **API Tokens**
2. Click **Add** → **API Token**
3. **User**: `terraform@pve`
4. **Token ID**: `terraform-token`
5. **Privilege Separation**: Disabled (for full permissions)
6. **Comment**: "Terraform automation token"
7. **Copy the generated secret**

### 2. Required Permissions

The token needs these permissions:
- `VM.Allocate`, `VM.Clone`, `VM.Config.*`, `VM.PowerMgmt`
- `Datastore.AllocateSpace`, `Datastore.Audit`
- `Sys.Audit`, `Sys.Modify`
- `Pool.Audit`

## Quick Deployment

### Option 1: Direct API Script (Recommended)

1. **Update configuration in `create_talos_vms.sh`:**
   ```bash
   # Edit these variables
   PROXMOX_URL="https://YOUR_PROXMOX_IP:8006/api2/json"
   TOKEN_ID="terraform@pve!terraform-token"
   TOKEN_SECRET="your-token-secret-here"
   NODE="your-proxmox-node-name"
   ```

2. **Run the deployment script:**
   ```bash
   chmod +x create_talos_vms.sh
   ./create_talos_vms.sh
   ```

3. **Setup the Talos Kubernetes cluster:**
   ```bash
   chmod +x setup_talos_cluster.sh
   ./setup_talos_cluster.sh
   ```

### Option 2: Terraform (Alternative)

**Note**: The Terraform provider has compatibility issues with Proxmox VE 9.0+ due to deprecated `VM.Monitor` permission. Use the API script instead.

1. **Configure variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your settings
   ```

2. **Deploy with Terraform:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Complete Deployment Process

### Option 1: Master Script (Recommended)
```bash
# 1. Copy and configure terraform.tfvars
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings

# 2. Deploy the cluster
./deploy_talos_cluster.sh
```

This single script will:
- ✅ Check if VMs already exist (fails if they do)
- ✅ Create 3 VMs with proper specifications
- ✅ Configure the Talos Kubernetes cluster
- ✅ Bootstrap the cluster and retrieve kubeconfig

### Option 2: Step-by-Step Deployment
```bash
# Step 1: Create VMs
./create_talos_vms.sh

# Step 2: Setup Talos Cluster
./setup_talos_cluster.sh
```

### Cleanup
```bash
./cleanup_vms.sh
```

This will create a Talos Kubernetes cluster named "laternfly" with:
- 1 control plane (VM 400)
- 2 worker nodes (VMs 411, 412)

### Cluster Setup Features

The `setup_talos_cluster.sh` script automatically:
- ✅ Checks for `talosctl` installation
- ✅ Generates Talos machine configurations
- ✅ Applies configurations to all VMs
- ✅ Bootstraps the Kubernetes cluster
- ✅ Retrieves kubeconfig for kubectl access
- ✅ Verifies cluster status and node readiness
- ✅ Creates organized config files in `./talos-configs/`

## Post-Deployment: Manual Talos Configuration (Alternative)

If you prefer to configure Talos manually after VMs are created and running:

### 1. Generate Talos Machine Configs

```bash
# Generate cluster configuration
talosctl gen config talos-cluster https://10.10.21.110:6443

# This creates:
# - controlplane.yaml
# - worker.yaml
# - talosconfig
```

### 2. Apply Machine Configurations

```bash
# Control plane
talosctl apply-config --insecure --nodes 10.10.21.110 --file controlplane.yaml

# Workers
talosctl apply-config --insecure --nodes 10.10.21.111 --file worker.yaml
talosctl apply-config --insecure --nodes 10.10.21.112 --file worker.yaml
```

### 3. Bootstrap the Cluster

```bash
# Set endpoint
talosctl --talosconfig=./talosconfig config endpoint 10.10.21.110

# Bootstrap the cluster
talosctl --talosconfig=./talosconfig bootstrap --nodes 10.10.21.110
```

### 4. Retrieve Kubeconfig

```bash
# Get kubeconfig for kubectl
talosctl --talosconfig=./talosconfig kubeconfig .

# Use with kubectl
export KUBECONFIG=./kubeconfig
kubectl get nodes
```

## VM Specifications

- **OS Type**: Linux 2.6+ Kernel
- **CPU**: Host passthrough (4 cores, 1 socket)
- **Memory**: 6GB RAM
- **Storage**: 50GB disk (raw format)
- **SCSI Controller**: VirtIO SCSI
- **Network Model**: VirtIO
- **Boot Order**: CD-ROM first, then disk
- **Agent**: Disabled (not needed for Talos)

## Network Configuration

- **Bridge**: vmbr0
- **Firewall**: Disabled
- **MAC Addresses**: Pre-configured for consistent networking
- **IP Addresses**: Static (configured via Talos machine config)

## Troubleshooting

### Common Issues

1. **VM Creation Fails**:
   - Check API token permissions
   - Verify storage pool exists
   - Ensure Talos ISO is uploaded

2. **MAC Address Errors**:
   - Use valid unicast MAC addresses
   - Format: `XX:XX:XX:XX:XX:XX`

3. **Terraform Provider Issues**:
   - Use the direct API script instead
   - Provider has compatibility issues with Proxmox VE 9.0+

### Cleanup

**Delete VMs via API:**
```bash
# Stop and delete VMs
curl -k -X POST -H "Authorization: PVEAPIToken=terraform@pve!terraform-token=YOUR_SECRET" \
  "https://YOUR_PROXMOX_IP:8006/api2/json/nodes/YOUR_NODE/qemu/400/status/shutdown"

curl -k -X DELETE -H "Authorization: PVEAPIToken=terraform@pve!terraform-token=YOUR_SECRET" \
  "https://YOUR_PROXMOX_IP:8006/api2/json/nodes/YOUR_NODE/qemu/400"
# Repeat for VMs 411 and 412
```

**Or via Proxmox Web Interface:**
- Go to each VM → More → Destroy

## Files Overview

- `deploy_talos_cluster.sh`: **Master deployment script (recommended)**
- `cleanup_vms.sh`: VM cleanup script
- `create_talos_vms.sh`: VM creation script (step-by-step)
- `setup_talos_cluster.sh`: Talos cluster configuration script (step-by-step)
- `main.tf`: Terraform configuration (alternative)
- `variables.tf`: Terraform variables
- `outputs.tf`: Terraform outputs
- `terraform.tfvars.example`: Example configuration
- `README.md`: This documentation

## Security Considerations

⚠️ **Important**: 

1. **API Token Security**:
   - Store token secret securely
   - Use environment variables in production
   - Rotate tokens regularly

2. **Network Security**:
   - Configure firewall rules as needed
   - Use VPN for remote access
   - Enable TLS verification in production

3. **Production Recommendations**:
   - Use separate storage pools
   - Enable Proxmox backup
   - Monitor resource usage
   - Set up log aggregation

## Why Direct API Instead of Terraform?

The Terraform `telmate/proxmox` provider has compatibility issues with Proxmox VE 9.0+:

- **Issue**: Provider requests deprecated `VM.Monitor` permission
- **Cause**: Proxmox VE 9.0 removed this permission
- **Solution**: Use direct API calls for reliable deployment

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.