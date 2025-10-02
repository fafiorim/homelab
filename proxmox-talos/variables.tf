# Proxmox Provider Variables
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://10.10.21.31:8006/api2/json"
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID (format: user@realm!token-name)"
  type        = string
  default     = "terraform@pve!terraform-token"
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
  # Set this via environment variable or terraform.tfvars
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification for Proxmox API"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Proxmox node name where VMs will be created"
  type        = string
  default     = "firefly"  # Based on your command prompt
}

# Storage and Network Variables
variable "storage_pool" {
  description = "Proxmox storage pool name"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Network bridge name"
  type        = string
  default     = "vmbr0"
}

variable "iso_storage" {
  description = "Proxmox storage name where the Talos ISO is uploaded"
  type        = string
  default     = "local"
}

# Talos VM Configuration
variable "control_plane_ip" {
  description = "Control plane IP address"
  type        = string
  default     = "10.10.21.110"
}

variable "worker_node_01_ip" {
  description = "Worker node 01 IP address"
  type        = string
  default     = "10.10.21.111"
}

variable "worker_node_02_ip" {
  description = "Worker node 02 IP address"
  type        = string
  default     = "10.10.21.112"
}

variable "talos_iso" {
  description = "Talos ISO filename"
  type        = string
  default     = "talos-v1.11.1-amd64.iso"
}

# MAC Address Configuration
variable "control_plane_mac" {
  description = "MAC address for the control plane VM (format: xx:xx:xx:xx:xx:xx)"
  type        = string
  default     = "bc:24:11:82:9f:fb"
  validation {
    condition     = can(regex("^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$", var.control_plane_mac))
    error_message = "MAC address must be in format xx:xx:xx:xx:xx:xx or xx-xx-xx-xx-xx-xx"
  }
}

variable "worker_01_mac" {
  description = "MAC address for worker node 01 (format: xx:xx:xx:xx:xx:xx)"
  type        = string
  default     = "bc:24:11:51:6f:4d"
  validation {
    condition     = can(regex("^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$", var.worker_01_mac))
    error_message = "MAC address must be in format xx:xx:xx:xx:xx:xx or xx-xx-xx-xx-xx-xx"
  }
}

variable "worker_02_mac" {
  description = "MAC address for worker node 02 (format: xx:xx:xx:xx:xx:xx)"
  type        = string
  default     = "bc:24:11:82:9f:3c"
  validation {
    condition     = can(regex("^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$", var.worker_02_mac))
    error_message = "MAC address must be in format xx:xx:xx:xx:xx:xx or xx-xx-xx-xx-xx-xx"
  }
}