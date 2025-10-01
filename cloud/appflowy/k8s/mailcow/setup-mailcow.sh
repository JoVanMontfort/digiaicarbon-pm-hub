#!/bin/bash

set -e

echo "🚀 Deploying Mailcow on Kubernetes..."

# Step 1: Check available storage classes
echo "📦 Checking available storage classes..."
kubectl get storageclass

# Step 2: Create namespace and PVCs
echo "📁 Creating namespace and persistent volumes..."
kubectl apply -f 00-namespace.yaml

# Wait for PVCs to be bound
echo "⏳ Waiting for PVCs to be bound..."
sleep 10
kubectl get pvc -n mailcow

# Step 3: Generate secrets
echo "🔐 Generating secrets..."
./generate-secrets.sh

# Step 4: Apply configurations
kubectl apply -f 01-configmap.yaml
kubectl apply -f 02-postgresql.yaml

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgresql -n mailcow --timeout=300s

echo "✅ PostgreSQL is now running!"
kubectl get pods -n mailcow