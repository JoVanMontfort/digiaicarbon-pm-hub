#!/bin/bash

NAMESPACE="mailcow"

echo "📊 Checking all events in namespace: $NAMESPACE"

echo ""
echo "1. Recent events (last 20):"
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -20

echo ""
echo "2. Pod status:"
kubectl get pods -n $NAMESPACE -o wide

echo ""
echo "3. Service status:"
kubectl get svc -n $NAMESPACE

echo ""
echo "4. Detailed pod events:"
for pod in $(kubectl get pods -n $NAMESPACE -o name); do
    echo ""
    echo "📄 $pod:"
    kubectl describe $pod -n $NAMESPACE | grep -A 10 "Events:"
done