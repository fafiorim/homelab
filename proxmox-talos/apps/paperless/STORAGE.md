# Paperless Storage Configuration

## Overview
Paperless uses shared storage mounted from Proxmox NFS share directly to Talos worker nodes via hostPath volumes.

## Architecture

```
Proxmox firefly (10.10.21.31)
  └─ /mnt/pve/Ugreen_NFS_VM/containers/paperless/  (NFS share mounted in Proxmox)
       │
       ├─ Mounted to Talos Worker VMs via Proxmox mp0
       │    └─ /var/mnt/paperless (on each worker node)
       │         │
       │         └─ Exposed to Kubernetes pods via kubelet extraMounts
       │              └─ hostPath volumes in deployments
       │
       ├─ data/       → Paperless application data
       ├─ media/      → Uploaded documents and thumbnails  
       ├─ consume/    → Document intake directory
       ├─ export/     → Document export directory
       └─ postgres/   → PostgreSQL database files
```

## Setup Requirements

### 1. Proxmox Configuration (Automated in deploy script)
The infrastructure deployment script automatically:
- Adds `mp0` mount point to worker VMs during creation
- Maps `/mnt/pve/Ugreen_NFS_VM/containers/paperless` to `/var/mnt/paperless`

### 2. Talos Configuration (Automated in deploy script)
Worker patch files include kubelet extraMounts:
```yaml
machine:
  kubelet:
    extraMounts:
      - destination: /var/mnt/paperless
        type: bind
        source: /var/mnt/paperless
        options:
          - bind
          - rshared
          - rw
```

### 3. Kubernetes Deployment (Configured)
Deployments use hostPath volumes pointing to `/var/mnt/paperless/*`

## Manual Setup (For Existing Clusters)

If you already have a running Talos cluster and want to add Paperless storage:

### Step 1: Add storage to Proxmox VMs
```bash
# On Proxmox firefly
qm set 411 --mp0 /mnt/pve/Ugreen_NFS_VM/containers/paperless,mp=/var/mnt/paperless
qm set 412 --mp0 /mnt/pve/Ugreen_NFS_VM/containers/paperless,mp=/var/mnt/paperless

# Reboot VMs
qm reboot 411 && qm reboot 412
```

### Step 2: Apply Talos kubelet patch
```bash
cd proxmox-talos
talosctl --talosconfig talosconfig patch machineconfig \
  --nodes 10.10.21.111,10.10.21.112 \
  --patch @talos-configs/nfs-storage-patch.yaml
```

### Step 3: Deploy Paperless
The deployment will automatically use hostPath volumes.

## Verification

### Check storage mount on Talos nodes
```bash
talosctl --talosconfig talosconfig -n 10.10.21.111 ls /var/mnt/paperless
```

### Check pods can access storage
```bash
kubectl exec -n paperless deployment/paperless -- ls -la /usr/src/paperless/data
```

### Verify files persist
```bash
# On Proxmox
ls -la /mnt/pve/Ugreen_NFS_VM/containers/paperless/media/documents/
```

## Benefits of This Approach

1. **No NFS client needed in Talos** - Storage passes through from Proxmox
2. **Simple configuration** - Just hostPath volumes, no PV/PVC complexity
3. **Automatic replication** - Deploy script handles everything
4. **Shared storage** - All worker nodes access same data
5. **Easy backup** - Data visible directly in Proxmox filesystem

## Troubleshooting

### Storage not visible in pods
1. Check Proxmox mount: `ls /mnt/pve/Ugreen_NFS_VM/containers/paperless/` on firefly
2. Check VM config: `qm config 411 | grep mp0` on Proxmox
3. Check Talos mount: `talosctl -n 10.10.21.111 ls /var/mnt/paperless`
4. Check kubelet config: `talosctl -n 10.10.21.111 get machineconfig -o yaml | grep -A5 extraMounts`

### Permissions issues
The storage needs to be writable. On Proxmox:
```bash
chmod -R 777 /mnt/pve/Ugreen_NFS_VM/containers/paperless/
```

### Pod scheduling
Since we use hostPath, pods must run on nodes that have the mount (worker nodes only).
