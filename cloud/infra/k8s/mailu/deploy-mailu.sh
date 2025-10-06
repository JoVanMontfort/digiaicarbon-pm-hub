#!/bin/bash

set -e

echo "🚀 Deploying Mailu with existing PostgreSQL..."

# Step 1: Create secrets
echo "🔐 Step 1: Creating secrets..."
./mailu-secrets.sh

# Step 2: Apply configurations
echo "📋 Step 2: Applying configurations..."
kubectl apply -f mailu-configmap.yaml
kubectl apply -f mailu-core.yaml
kubectl apply -f mailu-services-direct.yaml

# Step 3: Basic database check
echo "🗃️ Step 3: Basic database check..."
./mailu-database-setup.sh

# Step 4: Wait for Mailu initialization
echo "⏳ Step 4: Waiting for Mailu initialization..."
./wait-for-mailu-init.sh

# Step 5: Check final status
echo "📊 Step 5: Final status check..."
kubectl get pods,svc -n mailcow

echo "✅ Mailu deployment completed!"
echo ""
echo "🌐 Access points:"
echo "   Admin:    http://mail.damno-solutions.be/admin"
echo "   Webmail:  http://mail.damno-solutions.be/webmail"
echo ""
echo "🔐 Default credentials: admin / password"
echo "⚠️  CHANGE THE DEFAULT PASSWORD IMMEDIATELY!"