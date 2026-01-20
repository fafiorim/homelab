# Immich - Self-hosted Photo and Video Management

## Overview
Immich is a high-performance self-hosted photo and video backup solution with machine learning features including facial recognition, object detection, and automatic tagging.

## Components
- **Immich Server**: Main API server (port 3001)
- **Immich Machine Learning**: AI/ML processing with Intel GPU acceleration
- **PostgreSQL**: Database with vector extension (pgvecto-rs)
- **Redis**: Job queue and caching

## Intel GPU Acceleration
The machine learning container uses the Intel integrated GPU (i5-12600H) via `/dev/dri` device passthrough for:
- Face recognition
- Object detection
- Image classification
- Video transcoding

## Storage
- **NFS Server**: 10.10.21.11
- **Upload Directory**: `/volume4/VM/containers/immich/upload` (100Gi)
- **Library Directory**: `/volume4/VM/containers/immich/library` (500Gi)
- **Access Mode**: ReadWriteMany (RWX) for shared storage

## Setup

### 1. Create Storage Directories on Proxmox
```bash
# On Proxmox firefly (has NFS mounted)
mkdir -p /mnt/pve/Ugreen_NFS_VM/containers/immich/{upload,library}
chmod -R 777 /mnt/pve/Ugreen_NFS_VM/containers/immich/
```

### 2. Deploy via ArgoCD
```bash
kubectl apply -f immich-app.yaml
```

### 3. Access
- **URL**: https://immich.botocudo.net
- **First Run**: Create admin account

## Configuration
Edit environment variables in `immich-server.yaml` and `immich-machine-learning.yaml` for:
- Database connection
- Redis connection
- Upload locations
- ML model cache

## GPU Requirements
- Intel integrated GPU must be accessible on worker nodes
- `/dev/dri` device must exist
- Container runs with `privileged: true` for GPU access
- `nodeSelector` ensures scheduling on worker nodes with GPU

## Monitoring
Check ML container logs for GPU detection:
```bash
kubectl logs -n immich -l app=immich-machine-learning
```

## Troubleshooting

### GPU Not Detected
```bash
# Check if GPU devices exist on nodes
kubectl exec -n immich <ml-pod> -- ls -la /dev/dri/
```

### Storage Issues
```bash
# Verify NFS mounts
kubectl exec -n immich <server-pod> -- df -h | grep immich
```

### Database Connection
```bash
# Check PostgreSQL logs
kubectl logs -n immich -l app=immich-postgres
```

## Notes
- PostgreSQL uses emptyDir (ephemeral) - similar to Paperless
- Photos and videos are stored on persistent NFS storage
- Machine learning models cached in pod (regenerated on restart)
- Database can be backed up via pg_dump if needed
