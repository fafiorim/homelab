terraform {terraform {terraform {terraform {

  required_providers {

    proxmox = {  required_providers {

      source  = "telmate/proxmox"

      version = "~> 3.0"    proxmox = {  required_providers {  required_version = ">= 1.0"

    }

  }      source  = "telmate/proxmox"

}

      version = "~> 3.0"    proxmox = {  required_providers {

provider "proxmox" {

  pm_api_url      = var.proxmox_api_url    }

  pm_user         = var.proxmox_user

  pm_password     = var.proxmox_password  }      source  = "telmate/proxmox"    proxmox = {

  pm_tls_insecure = var.proxmox_tls_insecure

}}



variable "proxmox_api_url" {      version = "~> 3.0"      source  = "Telmate/proxmox"

  type = string

}# Configure the Proxmox Provider



variable "proxmox_user" {provider "proxmox" {    }      version = "~> 2.9"

  type = string

}  pm_api_url      = var.proxmox_api_url



variable "proxmox_password" {  pm_user         = var.proxmox_user  }    }

  type      = string

  sensitive = true  pm_password     = var.proxmox_password

}

  pm_tls_insecure = var.proxmox_tls_insecure}    talos = {

variable "proxmox_tls_insecure" {

  type    = bool}

  default = true

}      source  = "siderolabs/talos"



variable "proxmox_node" {# Variables

  type = string

}variable "proxmox_api_url" {# Configure the Proxmox Provider      version = "~> 0.5"



variable "cluster_name" {  description = "Proxmox API URL"

  type = string

}  type        = stringprovider "proxmox" {    }



resource "proxmox_vm_qemu" "control_plane" {}

  name        = "talos-cp-1"

  target_node = var.proxmox_node  pm_api_url      = var.proxmox_api_url  }

  vmid        = 300

  memory      = 4096variable "proxmox_user" {

  cores       = 2

  cpu         = "x86-64-v2-AES"  description = "Proxmox user"  pm_user         = var.proxmox_user}

  onboot      = true

  scsihw      = "virtio-scsi-single"  type        = string

  boot        = "order=ide2;scsi0"

}  pm_password     = var.proxmox_password

  network {

    bridge  = "vmbr0"

    model   = "virtio"

    macaddr = "bc:24:11:82:9f:fb"variable "proxmox_password" {  pm_tls_insecure = var.proxmox_tls_insecure# Configure Proxmox provider

  }

  description = "Proxmox password"

  disks {

    scsi {  type        = string}provider "proxmox" {

      scsi0 {

        disk {  sensitive   = true

          storage  = "local-lvm"

          size     = "32G"}  pm_api_url      = var.proxmox_api_url

          iothread = true

        }

      }

    }variable "proxmox_tls_insecure" {# Variables  pm_user         = var.proxmox_user

    ide {

      ide2 {  description = "Skip TLS verification"

        cdrom {

          iso = "local:iso/talos-v1.11.1-amd64.iso"  type        = boolvariable "proxmox_api_url" {  pm_password     = var.proxmox_password

        }

      }  default     = true

    }

  }}  description = "Proxmox API URL"  pm_tls_insecure = var.proxmox_tls_insecure

}



resource "proxmox_vm_qemu" "workers" {

  count       = 2variable "proxmox_node" {  type        = string}

  name        = "talos-worker-${count.index + 1}"

  target_node = var.proxmox_node  description = "Proxmox node name"

  vmid        = 301 + count.index

  memory      = 8192  type        = string}

  cores       = 4

  cpu         = "x86-64-v2-AES"}

  onboot      = true

  scsihw      = "virtio-scsi-single"# Configure Talos provider

  boot        = "order=ide2;scsi0"

variable "cluster_name" {

  network {

    bridge  = "vmbr0"  description = "Talos cluster name"variable "proxmox_user" {provider "talos" {}

    model   = "virtio"

    macaddr = count.index == 0 ? "bc:24:11:51:6f:4d" : "bc:24:11:e3:7a:2c"  type        = string

  }

}  description = "Proxmox user"

  disks {

    scsi {

      scsi0 {

        disk {# Control Plane VM  type        = string# Validate that IP lists match node counts

          storage  = "local-lvm"

          size     = "32G"resource "proxmox_vm_qemu" "control_plane" {

          iothread = true

        }  name        = "talos-cp-1"}locals {

      }

    }  target_node = var.proxmox_node

    ide {

      ide2 {  vmid        = 300  control_plane_ip_count = length(var.control_plane_ips)

        cdrom {

          iso = "local:iso/talos-v1.11.1-amd64.iso"  

        }

      }  # VM Configurationvariable "proxmox_password" {  worker_ip_count        = length(var.worker_ips)

    }

  }  memory   = 4096

}

  cores    = 2  description = "Proxmox password"  

output "expected_ips" {

  value = {  cpu      = "x86-64-v2-AES"

    control_plane = "10.10.21.110"

    worker_1      = "10.10.21.111"  onboot   = true  type        = string  # Validation - will cause plan to fail if counts don't match

    worker_2      = "10.10.21.112"

  }  

}
  # Network with fixed MAC address  sensitive   = true  validate_control_plane_ips = local.control_plane_ip_count == var.control_plane_count ? null : file("ERROR: control_plane_ips length (${local.control_plane_ip_count}) must match control_plane_count (${var.control_plane_count})")

  network {

    bridge   = "vmbr0"}  validate_worker_ips        = local.worker_ip_count == var.worker_count ? null : file("ERROR: worker_ips length (${local.worker_ip_count}) must match worker_count (${var.worker_count})")

    model    = "virtio"

    macaddr  = "bc:24:11:82:9f:fb"}

  }

  variable "proxmox_tls_insecure" {

  # Disk configuration

  disks {  description = "Skip TLS verification"# Generate Talos machine secrets

    scsi {

      scsi0 {  type        = boolresource "talos_machine_secrets" "cluster" {}

        disk {

          storage = "local-lvm"  default     = true

          size    = "32G"

          iothread = true}# Generate Talos machine configurations

        }

      }data "talos_machine_configuration" "controlplane" {

    }

    ide {variable "proxmox_node" {  cluster_name     = var.cluster_name

      ide2 {

        cdrom {  description = "Proxmox node name"  machine_type     = "controlplane"

          iso = "local:iso/talos-v1.11.1-amd64.iso"

        }  type        = string  cluster_endpoint = "https://${var.cluster_vip}:6443"

      }

    }}  machine_secrets  = talos_machine_secrets.cluster.machine_secrets

  }

  }

  # Boot configuration

  boot = "order=ide2;scsi0"variable "cluster_name" {

  

  # SCSI controller  description = "Talos cluster name"data "talos_machine_configuration" "worker" {

  scsihw = "virtio-scsi-single"

    type        = string  cluster_name     = var.cluster_name

  # Skip cloud-init

  skip_ipv4 = true}  machine_type     = "worker"

  skip_ipv6 = true

}  cluster_endpoint = "https://${var.cluster_vip}:6443"



# Worker VMs# Control Plane VM  machine_secrets  = talos_machine_secrets.cluster.machine_secrets

resource "proxmox_vm_qemu" "workers" {

  count       = 2resource "proxmox_vm_qemu" "control_plane" {}

  name        = "talos-worker-${count.index + 1}"

  target_node = var.proxmox_node  name        = "talos-cp-1"

  vmid        = 301 + count.index

    target_node = var.proxmox_node# Create control plane VMs

  # VM Configuration

  memory   = 8192  vmid        = 300resource "proxmox_vm_qemu" "control_plane" {

  cores    = 4

  cpu      = "x86-64-v2-AES"    count = var.control_plane_count

  onboot   = true

    # VM Configuration  

  # Network with fixed MAC addresses

  network {  memory   = 4096  name        = "${var.cluster_name}-cp-${count.index + 1}"

    bridge   = "vmbr0"

    model    = "virtio"  cores    = 2  target_node = var.proxmox_node

    macaddr  = count.index == 0 ? "bc:24:11:51:6f:4d" : "bc:24:11:e3:7a:2c"

  }  cpu      = "x86-64-v2-AES"  vmid        = var.control_plane_vm_id_base + count.index

  

  # Disk configuration  onboot   = true  

  disks {

    scsi {    # VM Resources

      scsi0 {

        disk {  # Network with fixed MAC address  cores   = var.control_plane_cpu_cores

          storage = "local-lvm"

          size    = "32G"  network {  memory  = var.control_plane_memory

          iothread = true

        }    bridge   = "vmbr0"  sockets = 1

      }

    }    model    = "virtio"  

    ide {

      ide2 {    macaddr  = "bc:24:11:82:9f:fb"  # Boot configuration

        cdrom {

          iso = "local:iso/talos-v1.11.1-amd64.iso"  }  bios = "ovmf"

        }

      }    machine = "q35"

    }

  }  # Disk configuration  

  

  # Boot configuration  disks {  # OS Disk

  boot = "order=ide2;scsi0"

      scsi {  disk {

  # SCSI controller

  scsihw = "virtio-scsi-single"      scsi0 {    size    = var.control_plane_disk_size

  

  # Skip cloud-init        disk {    type    = "scsi"

  skip_ipv4 = true

  skip_ipv6 = true          storage = "local-lvm"    storage = var.proxmox_storage

}

          size    = "32G"    cache   = "writethrough"

# Outputs

output "control_plane_vm_id" {          iothread = true    ssd     = 1

  value = proxmox_vm_qemu.control_plane.vmid

}        }  }



output "worker_vm_ids" {      }  

  value = proxmox_vm_qemu.workers[*].vmid

}    }  # Network



output "expected_ips" {    ide {  network {

  value = {

    control_plane = "10.10.21.110 (MAC: bc:24:11:82:9f:fb)"      ide2 {    model  = "virtio"

    worker_1      = "10.10.21.111 (MAC: bc:24:11:51:6f:4d)"

    worker_2      = "10.10.21.112 (MAC: bc:24:11:e3:7a:2c)"        cdrom {    bridge = var.proxmox_bridge

  }

}          iso = "local:iso/talos-v1.11.1-amd64.iso"  }

        }  

      }  # Cloud-init

    }  os_type = "cloud-init"

  }  ipconfig0 = "ip=${var.control_plane_ips[count.index]}/${var.network_cidr_bits},gw=${var.network_gateway}"

    nameserver = var.network_nameserver

  # Boot configuration  

  boot = "order=ide2;scsi0"  # Talos ISO

    iso = "${var.proxmox_storage}:iso/${var.talos_iso_name}"

  # SCSI controller  

  scsihw = "virtio-scsi-single"  # VM Settings

    agent    = 0

  # Skip cloud-init  onboot   = true

  skip_ipv4 = true  startup  = "order=1,up=30"

  skip_ipv6 = true  

}  # Wait for network

  depends_on = [

# Worker VMs    talos_machine_secrets.cluster

resource "proxmox_vm_qemu" "workers" {  ]

  count       = 2  

  name        = "talos-worker-${count.index + 1}"  # Apply Talos configuration after VM is ready

  target_node = var.proxmox_node  provisioner "local-exec" {

  vmid        = 301 + count.index    command = <<-EOT

        # Wait for VM to be accessible

  # VM Configuration      timeout 300 bash -c 'until nc -z ${var.control_plane_ips[count.index]} 50000; do sleep 5; done'

  memory   = 8192      

  cores    = 4      # Apply machine configuration

  cpu      = "x86-64-v2-AES"      echo '${data.talos_machine_configuration.controlplane.machine_configuration}' > /tmp/controlplane-${count.index}.yaml

  onboot   = true      talosctl apply-config --insecure --nodes ${var.control_plane_ips[count.index]} --file /tmp/controlplane-${count.index}.yaml

        

  # Network with fixed MAC addresses      # Clean up temp file

  network {      rm -f /tmp/controlplane-${count.index}.yaml

    bridge   = "vmbr0"    EOT

    model    = "virtio"  }

    macaddr  = count.index == 0 ? "bc:24:11:51:6f:4d" : "bc:24:11:e3:7a:2c"}

  }

  # Create worker VMs

  # Disk configurationresource "proxmox_vm_qemu" "worker" {

  disks {  count = var.worker_count

    scsi {  

      scsi0 {  name        = "${var.cluster_name}-worker-${count.index + 1}"

        disk {  target_node = var.proxmox_node

          storage = "local-lvm"  vmid        = var.worker_vm_id_base + count.index

          size    = "32G"  

          iothread = true  # VM Resources

        }  cores   = var.worker_cpu_cores

      }  memory  = var.worker_memory

    }  sockets = 1

    ide {  

      ide2 {  # Boot configuration

        cdrom {  bios = "ovmf"

          iso = "local:iso/talos-v1.11.1-amd64.iso"  machine = "q35"

        }  

      }  # OS Disk

    }  disk {

  }    size    = var.worker_disk_size

      type    = "scsi"

  # Boot configuration    storage = var.proxmox_storage

  boot = "order=ide2;scsi0"    cache   = "writethrough"

      ssd     = 1

  # SCSI controller  }

  scsihw = "virtio-scsi-single"  

    # Network

  # Skip cloud-init  network {

  skip_ipv4 = true    model  = "virtio"

  skip_ipv6 = true    bridge = var.proxmox_bridge

}  }

  

# Outputs  # Cloud-init

output "control_plane_vm_id" {  os_type = "cloud-init"

  value = proxmox_vm_qemu.control_plane.vmid  ipconfig0 = "ip=${var.worker_ips[count.index]}/${var.network_cidr_bits},gw=${var.network_gateway}"

}  nameserver = var.network_nameserver

  

output "worker_vm_ids" {  # Talos ISO

  value = proxmox_vm_qemu.workers[*].vmid  iso = "${var.proxmox_storage}:iso/${var.talos_iso_name}"

}  

  # VM Settings

output "expected_ips" {  agent    = 0

  value = {  onboot   = true

    control_plane = "10.10.21.110 (MAC: bc:24:11:82:9f:fb)"  startup  = "order=2,up=60"

    worker_1      = "10.10.21.111 (MAC: bc:24:11:51:6f:4d)"  

    worker_2      = "10.10.21.112 (MAC: bc:24:11:e3:7a:2c)"  # Wait for control planes

  }  depends_on = [

}    proxmox_vm_qemu.control_plane
  ]
  
  # Apply Talos configuration after VM is ready
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for VM to be accessible
      timeout 300 bash -c 'until nc -z ${var.worker_ips[count.index]} 50000; do sleep 5; done'
      
      # Apply machine configuration
      echo '${data.talos_machine_configuration.worker.machine_configuration}' > /tmp/worker-${count.index}.yaml
      talosctl apply-config --insecure --nodes ${var.worker_ips[count.index]} --file /tmp/worker-${count.index}.yaml
      
      # Clean up temp file
      rm -f /tmp/worker-${count.index}.yaml
    EOT
  }
}

# Bootstrap the cluster (only on first control plane)
resource "null_resource" "cluster_bootstrap" {
  depends_on = [
    proxmox_vm_qemu.control_plane,
    proxmox_vm_qemu.worker
  ]
  
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for all nodes to be ready
      sleep 120
      
      # Generate talosconfig
      talos_generate_config_helper() {
        talosctl gen config ${var.cluster_name} https://${var.cluster_vip}:6443 --output-dir ./configs/
        talosctl --talosconfig ./configs/talosconfig config endpoint ${join(" ", var.control_plane_ips)}
      }
      
      # Generate config if not exists
      if [ ! -f ./configs/talosconfig ]; then
        talos_generate_config_helper
      fi
      
      # Bootstrap cluster on first control plane
      talosctl --talosconfig ./configs/talosconfig bootstrap --nodes ${var.control_plane_ips[0]}
      
      # Wait for cluster to be ready
      sleep 60
      
      # Generate kubeconfig
      talosctl --talosconfig ./configs/talosconfig kubeconfig ./configs/kubeconfig --nodes ${var.control_plane_ips[0]}
      
      echo "Cluster bootstrap completed!"
      echo "Talos config: ./configs/talosconfig"
      echo "Kubeconfig: ./configs/kubeconfig"
    EOT
  }
}