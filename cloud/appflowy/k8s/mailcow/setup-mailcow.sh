#!/bin/bash

set -e

echo "🚀 Deploying Mailcow on Kubernetes..."

# Create namespace
kubectl apply -f 00-namespace.yaml

# Generate secrets
./generate-secrets.sh

# Apply configurations
kubectl apply -f 01-configmap.yaml
kubectl apply -f 02-postgresql.yaml

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgresql -n mailcow --timeout=300s

# Deploy Mailcow core
kubectl apply -f 03-mailcow-core.yaml

# Wait for pods to be ready
echo "⏳ Waiting for Mailcow pods to be ready..."
kubectl wait --for=condition=ready pod -l app=mailcow -n mailcow --timeout=300s

# Expose services
kubectl apply -f 04-services.yaml

# Get external IPs
echo "📊 Getting service information..."
kubectl get svc -n mailcow

echo "✅ Mailcow deployment completed!"
echo "📧 Update your DNS records to point to the external IPs above"