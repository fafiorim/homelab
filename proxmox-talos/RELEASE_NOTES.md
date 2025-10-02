# Release Notes

## v0.1.0 - ArgoCD GitOps Integration (2025-10-02)

### 🎉 Major Features

#### **Complete GitOps Integration**
- **ArgoCD Installation**: Official Helm chart with custom configuration
- **Configurable Git Repository**: Easy switching between repositories
- **Template System**: Dynamic manifest generation from templates
- **Enhanced CLI**: New commands for GitOps workflow

#### **New Commands**
- `./talos-cluster.sh argocd` - Install ArgoCD for GitOps
- `./talos-cluster.sh apps` - Deploy applications via ArgoCD
- `./talos-cluster.sh argocd-info` - Show ArgoCD access information

#### **New Scripts**
- `install-argocd.sh` - ArgoCD installation with custom values
- `deploy-apps.sh` - Application deployment with configurable repository
- `update-git-repo.sh` - Interactive repository configuration

### 📚 Documentation

#### **New Documentation**
- `README-GITOPS.md` - Complete GitOps guide and workflow
- Enhanced main README with GitOps integration
- Comprehensive examples and usage instructions

#### **Configuration**
- Git repository configuration in `cluster.conf`
- Template files for application manifests
- Updated `.gitignore` for generated files

### 🔧 Technical Improvements

#### **Infrastructure**
- **Proxmox API**: Pure API approach (Terraform removed)
- **Talos Linux**: Immutable, API-managed OS
- **Kubernetes**: v1.34.0 with Talos v1.11.1
- **ArgoCD**: Latest stable version with custom configuration

#### **GitOps Workflow**
- **Repository Configuration**: `git_repo_url` and `git_repo_branch` in `cluster.conf`
- **Template System**: `{{GIT_REPO_URL}}` and `{{GIT_REPO_BRANCH}}` placeholders
- **Dynamic Generation**: Manifests generated from templates
- **Automatic Sync**: Applications sync automatically from Git

### 🚀 Usage

#### **Quick Start**
```bash
# 1. Deploy cluster
./talos-cluster.sh deploy --force

# 2. Install ArgoCD
./talos-cluster.sh argocd

# 3. Deploy applications
./talos-cluster.sh apps

# 4. Check status
./talos-cluster.sh status
```

#### **Repository Configuration**
```bash
# Edit cluster.conf
git_repo_url = "https://github.com/your-username/your-repo"
git_repo_branch = "main"

# Or use interactive script
./update-git-repo.sh
```

### 📊 Statistics

- **Files Added**: 16 new files
- **Lines Added**: 975+ lines of code
- **New Commands**: 3 new CLI commands
- **New Scripts**: 3 new helper scripts
- **Documentation**: 2 new documentation files

### 🧪 Testing

#### **End-to-End Testing**
- ✅ Complete cluster deployment from scratch
- ✅ ArgoCD installation and configuration
- ✅ Application deployment via GitOps
- ✅ Repository configuration changes
- ✅ All CLI commands and scripts

#### **Tested Workflows**
- ✅ Cleanup → Deploy → ArgoCD → Apps
- ✅ Repository configuration updates
- ✅ Status monitoring and access information
- ✅ Error handling and edge cases

### 🔗 Links

- **Repository**: https://github.com/fafiorim/homelab
- **Release**: https://github.com/fafiorim/homelab/releases/tag/v0.1.0
- **Documentation**: See README.md and README-GITOPS.md

### 🎯 Next Steps

- **Production Ready**: Complete GitOps solution
- **Easy Customization**: Configurable for any repository
- **Comprehensive Documentation**: Full guides and examples
- **Tested Workflow**: End-to-end verified functionality

---

**This release represents a complete GitOps solution for homelab environments, making it easy to deploy and manage applications with ArgoCD and configurable Git repositories.**
