#!/bin/bash

# Comprehensive check script
echo "=== Checking Deployment ==="
kubectl get deployment appflowy -n appflowy

echo -e "\n=== Checking Pods ==="
kubectl get pods -n appflowy -l app=appflowy

echo -e "\n=== Checking Current Image ==="
kubectl get deployment appflowy -n appflowy -o jsonpath='{.spec.template.spec.containers[0].image}'

echo -e "\n=== Checking Rollout Status ==="
kubectl rollout status deployment/appflowy -n appflowy --timeout=10s

echo -e "\n=== Checking Namespace ==="
kubectl get namespace appflowy

# 1. Check current image
echo "Current image:"
kubectl get deployment appflowy -n appflowy -o jsonpath='{.spec.template.spec.containers[0].image}'

# 2. Verify your custom image exists
echo -e "\nChecking if custom image exists in GHCR..."
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://ghcr.io/v2/jovanmontfort/appflowy-web/tags/list" | jq .

# 3. Update to your custom image
echo -e "\nUpdating deployment to use custom image..."
kubectl set image deployment/appflowy -n appflowy appflowy=ghcr.io/jovanmontfort/appflowy-web:latest

# 4. Monitor the rollout
echo -e "\nMonitoring rollout..."
kubectl rollout status deployment/appflowy -n appflowy --timeout=60s

# 5. Check result
echo -e "\nFinal status:"
kubectl get deployment,po -n appflowy

# Comprehensive check script
echo "=== Checking Deployment ==="
kubectl get deployment appflowy -n appflowy

echo -e "\n=== Checking Pods ==="
kubectl get pods -n appflowy -l app=appflowy

echo -e "\n=== Checking Current Image ==="
kubectl get deployment appflowy -n appflowy -o jsonpath='{.spec.template.spec.containers[0].image}'

echo -e "\n=== Checking Rollout Status ==="
kubectl rollout status deployment/appflowy -n appflowy --timeout=10s

echo -e "\n=== Checking Namespace ==="
kubectl get namespace appflowy