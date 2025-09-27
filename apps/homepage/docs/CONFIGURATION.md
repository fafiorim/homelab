# Homepage Configuration Guide

## Current Updates Applied

### ✅ Fixed Pi-hole Logo
- Changed from `pihole.png` to `pi-hole.png` (correct icon name)

### ✅ Reorganized Services
- **Infrastructure** (4 columns): Proxmox Firefly, Proxmox DragonFly, TrueNAS, Ugreen NAS
- **Media Services** (1 column): Jellyfin
- **Network & Security** (1 column): Pi-hole
- **Kubernetes Management** (2 columns): Homepage Dashboard, Cluster Overview

### ✅ Clean Color Background
- Current background: Dark slate color (#1e293b)
- Clean, minimal design without background image
- Subtle hover effects for better interactivity

## Background Configuration Options

### Option 1: Image Background (Current)
```yaml
background: https://images.unsplash.com/photo-1518709268805-4e9042af2176?auto=format&fit=crop&w=2560&q=80
```

### Option 2: Color Background
```yaml
background: "#1e293b"  # Dark slate color
```

### Other Background Color Options:
```yaml
# Dark themes
background: "#0f172a"  # Very dark slate
background: "#1e1b4b"  # Dark indigo
background: "#312e81"  # Medium indigo
background: "#1f2937"  # Dark gray

# You can also use CSS gradients
background: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)"
```

## How to Switch Between Image and Color

### Method 1: Edit the ConfigMap directly
```bash
kubectl edit configmap homepage
```
Then modify the `background:` line in the `settings.yaml` section.

### Method 2: Update the manifest file and apply
1. Edit `/Users/franzvitorf/Documents/LABs/homelab/homelab/apps/homepage/manifests/homepage-complete-fixed.yaml`
2. Change the `background:` line in the `settings.yaml` section
3. Apply the changes:
```bash
kubectl apply -f manifests/homepage-complete-fixed.yaml
kubectl rollout restart deployment homepage
```

## Custom CSS Features Added

The custom CSS now includes:
- **Fixed background attachment** - Background stays in place when scrolling
- **Enhanced card readability** - Backdrop blur and transparency for better text visibility
- **Widget transparency** - Resource widgets have semi-transparent backgrounds
- **Improved contrast** - Better text readability over background images

## Alternative Background Images

If you want to try different background images, here are some good options:

### Technology/Server Room Themes:
```yaml
background: https://images.unsplash.com/photo-1558494949-ef010cbdcc31?auto=format&fit=crop&w=2560&q=80
background: https://images.unsplash.com/photo-1518709268805-4e9042af2176?auto=format&fit=crop&w=2560&q=80
background: https://images.unsplash.com/photo-1544197150-b99a580bb7a8?auto=format&fit=crop&w=2560&q=80
```

### Abstract/Digital Themes:
```yaml
background: https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=2560&q=80
background: https://images.unsplash.com/photo-1518709268805-4e9042af2176?auto=format&fit=crop&w=2560&q=80
```

### Minimal/Geometric:
```yaml
background: https://images.unsplash.com/photo-1557683316-973673baf926?auto=format&fit=crop&w=2560&q=80
```

## Access Your Updated Homepage

- **Primary**: http://10.10.21.200:30090
- **Backup**: http://10.10.21.211:30090 or http://10.10.21.212:30090

The Homepage now has:
- ✅ Fixed Pi-hole logo
- ✅ Better organized services (Ugreen NAS moved to Infrastructure)
- ✅ Beautiful background image with enhanced readability
- ✅ Easy switching between image and color backgrounds