#!/bin/bash

echo "🚀 Deploying Mailcow Core Services..."

echo "1. Testing database connection..."
kubectl exec -it postgresql-0 -n mailcow -- psql -U mailcow -d mailcow -c "SELECT version();"

echo "2. Deploying Mailcow core services..."
kubectl apply -f 03-mailcow-core.yaml

echo "3. Checking all pods..."
kubectl get pods -n mailcow

echo "4. Checking services..."
kubectl get svc -n mailcow

echo "✅ Mailcow core deployment completed!"