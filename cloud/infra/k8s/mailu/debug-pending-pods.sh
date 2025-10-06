#!/bin/bash

echo "🔍 Debugging Pending Pods..."

echo "1. Node resources:"
kubectl describe nodes | grep -A 10 "Allocatable"

echo ""
echo "2. PVC status:"
kubectl get pvc -n mailcow

echo ""
echo "3. Pod events:"
for pod in $(kubectl get pods -n mailcow -l app=mailu- -o name); do
    echo ""
    echo "📄 $pod:"
    kubectl describe -n mailcow $pod | grep -A 10 "Events:"
done

echo ""
echo "4. Recent cluster events:"
kubectl get events -n mailcow --sort-by='.lastTimestamp' | tail -10