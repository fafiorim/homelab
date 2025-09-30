# Control Plane VM Output
output "talos_control_plane_id" {
  description = "VM ID of the Talos control plane"
  value       = proxmox_vm_qemu.talos_control_plane.vmid
}

output "talos_control_plane_name" {
  description = "Name of the Talos control plane VM"
  value       = proxmox_vm_qemu.talos_control_plane.name
}

output "talos_control_plane_ip" {
  description = "IP address of the Talos control plane"
  value       = var.control_plane_ip
}

# Worker Node 01 Output
output "talos_worker_01_id" {
  description = "VM ID of the Talos worker node 01"
  value       = proxmox_vm_qemu.talos_worker_01.vmid
}

output "talos_worker_01_name" {
  description = "Name of the Talos worker node 01 VM"
  value       = proxmox_vm_qemu.talos_worker_01.name
}

output "talos_worker_01_ip" {
  description = "IP address of the Talos worker node 01"
  value       = var.worker_node_01_ip
}

# Worker Node 02 Output
output "talos_worker_02_id" {
  description = "VM ID of the Talos worker node 02"
  value       = proxmox_vm_qemu.talos_worker_02.vmid
}

output "talos_worker_02_name" {
  description = "Name of the Talos worker node 02 VM"
  value       = proxmox_vm_qemu.talos_worker_02.name
}

output "talos_worker_02_ip" {
  description = "IP address of the Talos worker node 02"
  value       = var.worker_node_02_ip
}

# Summary Output
output "cluster_summary" {
  description = "Summary of the Talos cluster"
  value = {
    control_plane = {
      name = proxmox_vm_qemu.talos_control_plane.name
      id   = proxmox_vm_qemu.talos_control_plane.vmid
      ip   = var.control_plane_ip
      mac  = "bc:24:11:82:9f:fb"
    }
    workers = [
      {
        name = proxmox_vm_qemu.talos_worker_01.name
        id   = proxmox_vm_qemu.talos_worker_01.vmid
        ip   = var.worker_node_01_ip
        mac  = "bc:24:11:51:6f:4d"
      },
      {
        name = proxmox_vm_qemu.talos_worker_02.name
        id   = proxmox_vm_qemu.talos_worker_02.vmid
        ip   = var.worker_node_02_ip
        mac  = "87:33:11:82:9f:3c"  # Please verify this MAC address
      }
    ]
  }
}