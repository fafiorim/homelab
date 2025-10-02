terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
  required_version = ">= 1.0"
}

# Configure the Proxmox Provider
provider "proxmox" {
  pm_api_url           = var.proxmox_api_url
  pm_api_token_id      = var.proxmox_api_token_id
  pm_api_token_secret  = var.proxmox_api_token_secret
  pm_tls_insecure      = var.proxmox_tls_insecure
}

# Talos Control Plane VM
resource "proxmox_vm_qemu" "talos_control_plane" {
  name        = "talos-control-plane"
  target_node = var.proxmox_node
  vmid        = 300
  
  # VM Configuration
  cores   = 4
  sockets = 1
  memory  = 4096
  
  # Boot configuration
  boot    = "order=ide2;scsi0"
  scsihw  = "virtio-scsi-pci"
  
  # Network configuration
  network {
    model    = "virtio"
    bridge   = var.network_bridge
    macaddr  = "bc:24:11:82:9f:fb"
    firewall = false
  }
  
  # Disk configuration
  disk {
    type    = "scsi"
    storage = var.storage_pool
    size    = "20G"
    format  = "raw"
  }
  
  # ISO configuration
  disk {
    type    = "ide"
    storage = var.iso_storage
    media   = "cdrom"
    file    = "${var.iso_storage}:iso/${var.talos_iso}"
    size    = "1"
  }
  
  # VM Options
  agent    = 0
  os_type  = "l26"
  cpu      = "host"
  numa     = false
  hotplug  = "network,disk,usb"
  
  # IP Configuration (using cloud-init style but for documentation)
  # IP: 10.10.21.110 - This will be configured via Talos machine config
  
  tags = "talos,control-plane"
  
  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }
}

# Talos Worker Node 01
resource "proxmox_vm_qemu" "talos_worker_01" {
  name        = "talos-worker-01"
  target_node = var.proxmox_node
  vmid        = 310
  
  # VM Configuration
  cores   = 2
  sockets = 1
  memory  = 2048
  
  # Boot configuration
  boot    = "order=ide2;scsi0"
  scsihw  = "virtio-scsi-pci"
  
  # Network configuration
  network {
    model    = "virtio"
    bridge   = var.network_bridge
    macaddr  = "bc:24:11:51:6f:4d"
    firewall = false
  }
  
  # Disk configuration
  disk {
    type    = "scsi"
    storage = var.storage_pool
    size    = "20G"
    format  = "raw"
  }
  
  # ISO configuration
  disk {
    type    = "ide"
    storage = var.iso_storage
    media   = "cdrom"
    file    = "${var.iso_storage}:iso/${var.talos_iso}"
    size    = "1"
  }
  
  # VM Options
  agent    = 0
  os_type  = "l26"
  cpu      = "host"
  numa     = false
  hotplug  = "network,disk,usb"
  
  # IP Configuration (using cloud-init style but for documentation)
  # IP: 10.10.21.111 - This will be configured via Talos machine config
  
  tags = "talos,worker"
  
  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }
}

# Talos Worker Node 02
resource "proxmox_vm_qemu" "talos_worker_02" {
  name        = "talos-worker-02"
  target_node = var.proxmox_node
  vmid        = 311
  
  # VM Configuration
  cores   = 2
  sockets = 1
  memory  = 2048
  
  # Boot configuration
  boot    = "order=ide2;scsi0"
  scsihw  = "virtio-scsi-pci"
  
  # Network configuration
  network {
    model    = "virtio"
    bridge   = var.network_bridge
    macaddr  = "87:33:11:82:9f:3c"  # Please verify this MAC address
    firewall = false
  }
  
  # Disk configuration
  disk {
    type    = "scsi"
    storage = var.storage_pool
    size    = "20G"
    format  = "raw"
  }
  
  # ISO configuration
  disk {
    type    = "ide"
    storage = var.iso_storage
    media   = "cdrom"
    file    = "${var.iso_storage}:iso/${var.talos_iso}"
    size    = "1"
  }
  
  # VM Options
  agent    = 0
  os_type  = "l26"
  cpu      = "host"
  numa     = false
  hotplug  = "network,disk,usb"
  
  # IP Configuration (using cloud-init style but for documentation)
  # IP: 10.10.21.112 - This will be configured via Talos machine config
  
  tags = "talos,worker"
  
  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }
}