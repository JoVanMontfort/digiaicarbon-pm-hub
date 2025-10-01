#!/bin/bash

echo "🔍 Debugging PostgreSQL crash..."

echo "1. Checking secrets:"
kubectl get secrets mailcow-secrets -n mailcow -o yaml

echo ""
echo "2. Checking PVC:"
kubectl get pvc -n mailcow
kubectl describe pvc data-postgresql-0 -n mailcow

echo ""
echo "3. Current pod status:"
kubectl get pod postgresql-0 -n mailcow -o wide

echo ""
echo "4. Last logs:"
kubectl logs postgresql-0 -n mailcow --previous 2>/dev/null || echo "No previous logs"

echo ""
echo "5. Current logs:"
kubectl logs postgresql-0 -n mailcow --tail=20