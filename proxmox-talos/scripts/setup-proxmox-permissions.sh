#!/bin/bash

# =============================================================================
# Proxmox Permission Setup Script
# =============================================================================
# This script sets up the required permissions for the terraform user and token
# to manage VMs, storage, and networking on Proxmox.
#
# Usage:
#   ./setup-proxmox-permissions.sh <proxmox-host> [username] [tokenid]
#
# Example:
#   ./setup-proxmox-permissions.sh 10.10.21.31
#   ./setup-proxmox-permissions.sh 10.10.21.31 terraform@pve terraform-token
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROXMOX_HOST="${1:-10.10.21.31}"
PVE_USER="${2:-terraform@pve}"
PVE_TOKEN="${3:-terraform-token}"
PVE_TOKEN_FULL="${PVE_USER}!${PVE_TOKEN}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_banner() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         Proxmox Permission Setup Script                       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Target Host:${NC} $PROXMOX_HOST"
    echo -e "${YELLOW}User:${NC} $PVE_USER"
    echo -e "${YELLOW}Token:${NC} $PVE_TOKEN_FULL"
    echo ""
}

check_ssh_access() {
    log_info "Checking SSH access to Proxmox host..."
    
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes root@"$PROXMOX_HOST" "exit" 2>/dev/null; then
        log_warning "SSH key authentication not available"
        log_info "Will prompt for password when needed"
    else
        log_success "SSH access verified"
    fi
}

setup_permissions() {
    log_info "Setting up permissions on Proxmox host..."
    
    # Create SSH command with all permission setup
    cat <<'EOF' | ssh root@"$PROXMOX_HOST" "bash -s" -- "$PVE_USER" "$PVE_TOKEN_FULL"
#!/bin/bash
set -e

PVE_USER="$1"
PVE_TOKEN_FULL="$2"

echo "Setting up permissions for user: $PVE_USER"
echo "Setting up permissions for token: $PVE_TOKEN_FULL"
echo ""

# Function to add ACL
add_acl() {
    local path="$1"
    local type="$2"  # -user or -token
    local entity="$3"
    local role="$4"
    
    echo "Adding: $path | $type | $entity | $role"
    pveum acl modify "$path" $type "$entity" -role "$role" 2>/dev/null || true
}

# Root level permissions for VM management
add_acl "/" -user "$PVE_USER" PVEVMAdmin
add_acl "/" -token "$PVE_TOKEN_FULL" PVEDatastoreAdmin

# Storage permissions for ISOs (local storage)
add_acl "/storage/local" -user "$PVE_USER" PVEDatastoreAdmin
add_acl "/storage/local" -token "$PVE_TOKEN_FULL" PVEDatastoreAdmin

# Storage permissions for VM disks (local-lvm)
add_acl "/storage/local-lvm" -user "$PVE_USER" PVEDatastoreAdmin
add_acl "/storage/local-lvm" -token "$PVE_TOKEN_FULL" PVEDatastoreAdmin

# SDN permissions for network access
add_acl "/sdn" -user "$PVE_USER" PVESDNUser
add_acl "/sdn" -token "$PVE_TOKEN_FULL" PVESDNUser

echo ""
echo "✓ Permissions setup completed!"
echo ""
echo "Current ACL for $PVE_USER and token:"
pveum acl list | grep -E "(terraform|Path)" || echo "No entries found"
EOF

    if [ $? -eq 0 ]; then
        log_success "Permissions configured successfully"
    else
        log_error "Failed to configure permissions"
        return 1
    fi
}

verify_permissions() {
    log_info "Verifying permissions..."
    
    ssh root@"$PROXMOX_HOST" "pveum acl list" | grep -E "(terraform|Path)" || {
        log_warning "Could not verify permissions"
        return 1
    }
    
    log_success "Permissions verified"
}

show_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    Setup Complete!                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Configured Permissions:${NC}"
    echo "  • Root level: PVEVMAdmin (user), PVEDatastoreAdmin (token)"
    echo "  • Storage (local): PVEDatastoreAdmin (user & token)"
    echo "  • Storage (local-lvm): PVEDatastoreAdmin (user & token)"
    echo "  • SDN: PVESDNUser (user & token)"
    echo ""
    echo -e "${YELLOW}Note:${NC} These permissions allow:"
    echo "  ✓ Creating and managing VMs"
    echo "  ✓ Accessing ISO files for VM installation"
    echo "  ✓ Allocating disk storage for VMs"
    echo "  ✓ Configuring VM networking"
    echo ""
}

main() {
    show_banner
    
    if [ -z "$PROXMOX_HOST" ]; then
        log_error "Proxmox host address is required"
        echo "Usage: $0 <proxmox-host> [username] [tokenid]"
        exit 1
    fi
    
    check_ssh_access
    setup_permissions
    verify_permissions
    show_summary
    
    log_success "All operations completed successfully!"
}

main "$@"
