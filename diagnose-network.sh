#!/bin/bash

echo "🔍 HOMELAB NETWORK DIAGNOSTICS"
echo "================================"
echo ""

# Set kubeconfig
export KUBECONFIG=/Users/franzvitorf/Documents/LABs/homelab/proxmox-talos/kubeconfig

echo "📋 1. CLUSTER STATUS"
echo "-------------------"
kubectl get nodes -o wide

echo ""
echo "📋 2. SERVICE STATUS"
echo "-------------------"
kubectl get svc -A | grep -E "(LoadBalancer|NodePort)"

echo ""
echo "📋 3. METALLB STATUS"
echo "-------------------"
echo "MetalLB Pods:"
kubectl get pods -n metallb-system
echo ""
echo "IP Address Pool:"
kubectl get ipaddresspool -n metallb-system -o yaml

echo ""
echo "📋 4. TRAEFIK STATUS"
echo "-------------------"
kubectl get pods -n traefik-system -o wide
echo ""
kubectl get svc -n traefik-system

echo ""
echo "📋 5. INGRESS STATUS"
echo "-------------------"
kubectl get ingress -A

echo ""
echo "📋 6. NETWORK CONNECTIVITY TESTS"
echo "--------------------------------"
echo "Testing cluster node connectivity..."
for node in 10.10.21.110 10.10.21.111 10.10.21.112; do
    echo -n "Node $node: "
    if ping -c 1 -W 2 $node >/dev/null 2>&1; then
        echo "✅ Reachable"
    else
        echo "❌ Unreachable"
    fi
done

echo ""
echo "Testing LoadBalancer IP..."
echo -n "LoadBalancer 10.10.21.201: "
if ping -c 1 -W 2 10.10.21.201 >/dev/null 2>&1; then
    echo "✅ Reachable"
else
    echo "❌ Unreachable"
fi

echo ""
echo "📋 7. NODEPORT ACCESSIBILITY TEST"
echo "--------------------------------"
echo "Testing NodePort access on reachable nodes..."

# Get Traefik NodePorts
HTTP_PORT=$(kubectl get svc -n traefik-system traefik -o jsonpath='{.spec.ports[?(@.name=="web")].nodePort}')
HTTPS_PORT=$(kubectl get svc -n traefik-system traefik -o jsonpath='{.spec.ports[?(@.name=="websecure")].nodePort}')
ADMIN_PORT=$(kubectl get svc -n traefik-system traefik -o jsonpath='{.spec.ports[?(@.name=="admin")].nodePort}')

echo "Traefik HTTP NodePort: $HTTP_PORT"
echo "Traefik HTTPS NodePort: $HTTPS_PORT"  
echo "Traefik Admin NodePort: $ADMIN_PORT"

for node in 10.10.21.110 10.10.21.111 10.10.21.112; do
    echo ""
    echo "Testing node $node..."
    if ping -c 1 -W 2 $node >/dev/null 2>&1; then
        echo -n "  HTTP ($HTTP_PORT): "
        if timeout 3 nc -z $node $HTTP_PORT 2>/dev/null; then
            echo "✅ Open"
        else
            echo "❌ Blocked/Closed"
        fi
        
        echo -n "  Admin ($ADMIN_PORT): "
        if timeout 3 nc -z $node $ADMIN_PORT 2>/dev/null; then
            echo "✅ Open"
        else
            echo "❌ Blocked/Closed"
        fi
    else
        echo "  ❌ Node unreachable - skipping port tests"
    fi
done

echo ""
echo "📋 8. METALLB TROUBLESHOOTING"
echo "----------------------------"
echo "Checking MetalLB speaker logs for ARP/BGP issues..."
kubectl logs -n metallb-system -l app=metallb,component=speaker --tail=10 --all-containers=true

echo ""
echo "📋 9. RECOMMENDATIONS"
echo "-------------------"
echo "Based on the diagnostics above:"
echo ""
echo "If nodes are unreachable:"
echo "  - Check Proxmox VM firewall settings"
echo "  - Verify Proxmox datacenter/node firewall rules"
echo "  - Check if VMs are on the correct network bridge"
echo ""
echo "If nodes are reachable but ports are blocked:"
echo "  - Check Proxmox firewall rules for the VMs"
echo "  - Verify Talos node configuration"
echo ""  
echo "If LoadBalancer IP is not working:"
echo "  - Check MetalLB speaker logs above"
echo "  - Verify MetalLB can announce the IP via ARP"
echo "  - Check if there are IP conflicts"
echo ""
echo "Quick fixes to try:"
echo "  1. Access via NodePort: http://10.10.21.112:$HTTP_PORT/"
echo "  2. Use kubectl port-forward for testing"
echo "  3. Check Proxmox firewall in web UI"

echo ""
echo "🎯 TO ACCESS YOUR SERVICES NOW:"
echo "------------------------------"
echo "If any node ports are open, you can access services via:"
echo "  - Homepage: http://[reachable-node]:$HTTP_PORT/ (with Host: homepage.botocudo.net header)"
echo "  - Grafana: http://[reachable-node]:$HTTP_PORT/ (with Host: grafana.botocudo.net header)"  
echo "  - Traefik Dashboard: http://[reachable-node]:$ADMIN_PORT/"
echo ""
echo "Or use port forwarding:"
echo "  kubectl port-forward -n homepage svc/homepage 8001:3000"
echo "  kubectl port-forward -n monitoring svc/grafana 8002:3000"
echo "  kubectl port-forward -n traefik-system svc/traefik 8080:8080"