#!/bin/bash

echo "🔐 Creating Mailu secrets..."

# Generate secrets
SECRET_KEY=$(openssl rand -hex 24)
DB_PASSWORD=$(kubectl get secret mailcow-secrets -n mailcow -o jsonpath='{.data.postgres-password}' | base64 -d)

# Create secrets
kubectl create secret generic mailu-secrets -n mailcow \
  --from-literal=secret-key="$SECRET_KEY" \
  --from-literal=db-password="$DB_PASSWORD" \
  --dry-run=client -o yaml > mailu-secrets.yaml

kubectl apply -f mailu-secrets.yaml

echo "✅ Mailu secrets created!"