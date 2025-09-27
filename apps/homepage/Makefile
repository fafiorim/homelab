# Homepage Kubernetes Deployment Makefile

.PHONY: help deploy status logs clean update config restart nodeport loadbalancer

# Default namespace
NAMESPACE ?= default
SERVICE_TYPE ?= nodeport

help: ## Show this help message
	@echo "Homepage Kubernetes Deployment"
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

deploy: ## Deploy Homepage with default settings
	@echo "Deploying Homepage..."
	./deploy.sh -n $(NAMESPACE) -s $(SERVICE_TYPE)

nodeport: ## Deploy with NodePort service
	@echo "Deploying Homepage with NodePort service..."
	./deploy.sh -n $(NAMESPACE) -s nodeport

loadbalancer: ## Deploy with LoadBalancer service
	@echo "Deploying Homepage with LoadBalancer service..."
	./deploy.sh -n $(NAMESPACE) -s loadbalancer

status: ## Check deployment status
	@echo "Checking Homepage deployment status..."
	kubectl get pods -l app.kubernetes.io/name=homepage -n $(NAMESPACE)
	kubectl get svc -l app.kubernetes.io/name=homepage -n $(NAMESPACE)
	kubectl get ingress -l app.kubernetes.io/name=homepage -n $(NAMESPACE) 2>/dev/null || true

logs: ## View application logs
	kubectl logs -l app.kubernetes.io/name=homepage -n $(NAMESPACE) --tail=100 -f

config: ## Edit configuration
	kubectl edit configmap homepage -n $(NAMESPACE)

restart: ## Restart the deployment
	kubectl rollout restart deployment/homepage -n $(NAMESPACE)
	kubectl rollout status deployment/homepage -n $(NAMESPACE)

update: ## Update to latest image
	kubectl set image deployment/homepage homepage=ghcr.io/gethomepage/homepage:latest -n $(NAMESPACE)
	kubectl rollout status deployment/homepage -n $(NAMESPACE)

port-forward: ## Setup port forwarding for local access
	@echo "Setting up port forwarding on http://localhost:3000"
	kubectl port-forward svc/homepage 3000:3000 -n $(NAMESPACE)

get-access: ## Show access information
	@echo "Homepage Access Information:"
	@echo "==========================="
	@NODE_IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'); \
	echo "NodePort: http://$$NODE_IP:30090"
	@echo "Port-forward: make port-forward"
	@LB_IP=$$(kubectl get svc homepage-lb -n $(NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null); \
	if [ -n "$$LB_IP" ]; then echo "LoadBalancer: http://$$LB_IP"; fi

backup-config: ## Backup current configuration
	@mkdir -p backups
	kubectl get configmap homepage -n $(NAMESPACE) -o yaml > backups/homepage-config-$$(date +%Y%m%d-%H%M%S).yaml
	@echo "Configuration backed up to backups/ directory"

validate: ## Validate Kubernetes manifests
	@echo "Validating Kubernetes manifests..."
	kubectl apply --dry-run=client -f manifests/homepage-complete.yaml
	@echo "Manifests are valid"

clean: ## Remove Homepage deployment
	@echo "Removing Homepage deployment..."
	kubectl delete -f manifests/homepage-complete.yaml --ignore-not-found=true
	kubectl delete -f manifests/service-loadbalancer.yaml --ignore-not-found=true 2>/dev/null || true
	@echo "Homepage deployment removed"

install-deps: ## Install required dependencies
	@echo "Checking dependencies..."
	@command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed. Please install kubectl."; exit 1; }
	@command -v make >/dev/null 2>&1 || { echo "make is required but not installed. Please install make."; exit 1; }
	@echo "All dependencies are installed"

cluster-info: ## Show cluster information
	kubectl cluster-info
	kubectl get nodes -o wide
	kubectl version --short

# Development targets
dev-deploy: ## Deploy for development with port-forward
	make deploy NAMESPACE=default SERVICE_TYPE=clusterip
	@echo "Starting port-forward for development access..."
	make port-forward

# Production targets
prod-deploy: ## Deploy for production with LoadBalancer
	make deploy NAMESPACE=homepage SERVICE_TYPE=loadbalancer

# Monitoring targets
watch: ## Watch deployment status
	watch kubectl get pods,svc,ingress -l app.kubernetes.io/name=homepage -n $(NAMESPACE)

events: ## Show recent events
	kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | grep homepage

describe: ## Describe homepage resources
	kubectl describe deployment homepage -n $(NAMESPACE)
	kubectl describe svc homepage -n $(NAMESPACE)
	kubectl describe configmap homepage -n $(NAMESPACE)