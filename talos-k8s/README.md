# Talos Kubernetes Cluster on Proxmox# Talos Kubernetes HA Cluster on Proxmox with Terraform



This repository contains Terraform configuration for deploying a Talos Linux Kubernetes cluster on Proxmox VE with fixed MAC addresses and DHCP reservations.This project provides Terraform templates to deploy a production-ready Talos Kubernetes High Availability cluster on Proxmox VE.



## 📋 Overview## 🏗️ Architecture



- **Architecture**: 1 Control Plane + 2 Worker nodes- **2 Control Plane Nodes** - HA etcd cluster and Kubernetes API

- **Talos Version**: v1.11.1  - **2 Worker Nodes** - Application workloads

- **Deployment Method**: Terraform with Proxmox provider- **Load Balancer** - Optional HAProxy for API endpoint

- **Network**: Fixed MAC addresses with DHCP reservations- **Automated Setup** - Complete cluster deployment and configuration

- **Storage**: 32GB disk per node on local-lvm

- **CPU**: Optimized x86-64-v2-AES with dedicated cores## 📋 Prerequisites

- **Memory**: 4GB Control Plane, 8GB Workers

- Proxmox VE cluster

## 🚀 Quick Start- Terraform >= 1.0

- `talosctl` CLI tool

### Prerequisites- `kubectl` CLI tool

- Network access to Proxmox API

1. **Proxmox VE** server with API access

2. **Terraform** installed (v1.0+)## 🚀 Quick Start

3. **talosctl** CLI tool installed

4. **kubectl** CLI tool installed1. **Clone and configure:**

5. **DHCP reservations** configured for fixed MAC addresses   ```bash

   git clone <repository-url>

### DHCP Reservations Required   cd talos-k8s-proxmox

   cp terraform.tfvars.example terraform.tfvars

Configure these MAC-to-IP reservations in your DHCP server:   # Edit terraform.tfvars with your settings

   ```

```

bc:24:11:82:9f:fb → 10.10.21.110 (Control Plane)2. **Deploy infrastructure:**

bc:24:11:51:6f:4d → 10.10.21.111 (Worker 1)   ```bash

bc:24:11:e3:7a:2c → 10.10.21.112 (Worker 2)   terraform init

```   terraform plan

   terraform apply

### Deployment   ```



1. **Deploy the VMs:**3. **Configure cluster:**

   ```bash   ```bash

   ./deploy.sh   ./scripts/setup-cluster.sh

   ```   ```



2. **Configure the cluster:**## 📁 Project Structure

   ```bash

   ./configure-cluster.sh```

   ```├── terraform/           # Terraform configurations

├── scripts/            # Automation scripts

3. **Verify deployment:**├── configs/            # Talos configurations

   ```bash├── docs/               # Documentation

   kubectl get nodes -o wide└── examples/           # Example configurations

   ``````



4. **Cleanup (when needed):**## 🔧 Configuration

   ```bash

   ./cleanup.sh### 1. Create Proxmox API Token (Recommended)

   ```For security, create an API token instead of using root credentials:



## 🔧 Configuration1. In Proxmox Web UI: **Datacenter** → **Permissions** → **API Tokens** → **Add**

2. Settings:

### Terraform Variables   - **User:** `root@pam`

   - **Token ID:** `terraform`

Edit `terraform/terraform.tfvars`:   - **Privilege Separation:** `Unchecked` (for full access)

3. Copy the generated secret (you won't see it again!)

```hcl

proxmox_api_url      = "https://10.10.21.31:8006/api2/json"### 2. Configure Terraform Variables

proxmox_user         = "root@pam"

proxmox_password     = "your-password"Key variables to configure in `terraform.tfvars`:

proxmox_tls_insecure = true

proxmox_node         = "firefly"- `proxmox_api_token_id` - API token ID (e.g., `root@pam!terraform`)

cluster_name         = "talos-homelab"- `proxmox_api_token_secret` - API token secret

```- `cluster_name` - Name for your cluster

- `control_plane_ips` - List of static IPs for control planes

### VM Specifications- `worker_ips` - List of static IPs for workers



- **Control Plane**: VM ID 300, 4GB RAM, 2 CPU cores, MAC: bc:24:11:82:9f:fb**Important:** Ensure your IP lists match your node counts:

- **Worker 1**: VM ID 301, 8GB RAM, 4 CPU cores, MAC: bc:24:11:51:6f:4d- `control_plane_ips` length must equal `control_plane_count`

- **Worker 2**: VM ID 302, 8GB RAM, 4 CPU cores, MAC: bc:24:11:e3:7a:2c- `worker_ips` length must equal `worker_count`



## 📂 Project Structure### 3. Network Configuration



```- Control Planes: `["10.10.21.200", "10.10.21.201"]`

.- Workers: `["10.10.21.210", "10.10.21.211"]`

├── deploy.sh              # Main deployment script- Load Balancer VIP: `10.10.21.110`

├── configure-cluster.sh   # Cluster configuration script  

├── cleanup.sh            # Cleanup script## 📖 Documentation

├── terraform/

│   ├── main.tf           # Terraform configuration- [Deployment Guide](docs/deployment.md)

│   └── terraform.tfvars  # Variables configuration- [Configuration Reference](docs/configuration.md)

├── _out/                 # Generated Talos configs (created during deployment)- [Troubleshooting](docs/troubleshooting.md)

└── README.md            

```## 🛡️ Security



## 🔍 Troubleshooting- Automatic certificate generation

- Encrypted etcd cluster

### VMs Not Getting Expected IPs- RBAC enabled by default

- Network policies ready

1. **Check DHCP reservations** are configured correctly

2. **Verify MAC addresses** match the configuration## 🔄 Maintenance

3. **Wait longer** for DHCP lease renewal

4. **Check network connectivity** to VMs- Automated backup scripts

- Rolling update procedures

### Terraform Issues- Monitoring setup guides



1. **Provider initialization:**## 📞 Support

   ```bash

   cd terraform && terraform init- GitHub Issues for bug reports

   ```- Discussions for questions

- Wiki for community contributions

2. **Validate configuration:**

   ```bash---

   cd terraform && terraform validate

   ```**Made with ❤️ for the Talos and Kubernetes community**

3. **Check Proxmox connectivity:**
   ```bash
   curl -k https://your-proxmox:8006/api2/json/version
   ```

### Talos Configuration Issues

1. **Check node connectivity:**
   ```bash
   talosctl health --nodes <node-ip>
   ```

2. **View node logs:**
   ```bash
   talosctl logs --nodes <node-ip>
   ```

3. **Reset cluster (if needed):**
   ```bash
   talosctl reset --nodes <all-nodes> --graceful=false
   ```

## 🛠️ Advanced Usage

### Manual Terraform Commands

```bash
cd terraform

# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply

# Destroy
terraform destroy
```

### Manual Talos Configuration

```bash
# Generate configs
talosctl gen config talos-homelab https://10.10.21.110:6443 --output-dir _out

# Apply configs
talosctl apply-config --insecure --nodes 10.10.21.110 --file _out/controlplane.yaml
talosctl apply-config --insecure --nodes 10.10.21.111,10.10.21.112 --file _out/worker.yaml

# Bootstrap cluster
talosctl config endpoint 10.10.21.110
talosctl config node 10.10.21.110
talosctl bootstrap --nodes 10.10.21.110

# Get kubeconfig
talosctl kubeconfig .
```

## 📋 Features

- ✅ **Terraform-managed** - Infrastructure as Code
- ✅ **Fixed MAC addresses** - Predictable networking
- ✅ **DHCP reservations** - Consistent IP assignments  
- ✅ **Optimized performance** - x86-64-v2-AES, iothread
- ✅ **Automated deployment** - Single command execution
- ✅ **Easy cleanup** - Complete teardown capability

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.