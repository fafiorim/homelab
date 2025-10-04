#!/bin/bash

# Create self-signed certificates for all services
DOMAINS=("homepage.botocudo.net" "argocd.botocudo.net" "grafana.botocudo.net" "prometheus.botocudo.net" "npm.botocudo.net")

for domain in "${DOMAINS[@]}"; do
    echo "Creating certificate for $domain..."
    
    # Create private key
    openssl genpkey -algorithm RSA -out ${domain}.key -pkcs8
    
    # Create certificate signing request
    openssl req -new -key ${domain}.key -out ${domain}.csr -subj "/CN=$domain/O=Homelab/C=US"
    
    # Create self-signed certificate
    openssl x509 -req -in ${domain}.csr -signkey ${domain}.key -out ${domain}.crt -days 365
    
    # Create Kubernetes TLS secret
    kubectl create secret tls ${domain%-*}-tls \
        --cert=${domain}.crt \
        --key=${domain}.key \
        --namespace=$(echo $domain | cut -d'.' -f1 | sed 's/homepage/homepage/; s/argocd/argocd/; s/grafana/monitoring/; s/prometheus/monitoring/; s/npm/nginx-proxy-manager/') \
        --dry-run=client -o yaml > ${domain%-*}-tls-secret.yaml
    
    echo "Generated: ${domain%-*}-tls-secret.yaml"
    
    # Clean up temp files
    rm ${domain}.csr ${domain}.crt ${domain}.key
done

echo "All certificates created! Apply them with:"
echo "kubectl apply -f *-tls-secret.yaml"