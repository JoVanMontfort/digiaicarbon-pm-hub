#!/bin/bash

echo "Cleaning up unnecessary pods..."

# Delete succeeded pods
echo "Deleting succeeded pods..."
kubectl delete pods --all-namespaces --field-selector=status.phase==Succeeded --wait=false

# Delete failed pods
echo "Deleting failed pods..."
kubectl delete pods --all-namespaces --field-selector=status.phase==Failed --wait=false

kubectl delete pods --all-namespaces --field-selector=status.phase==CrashLoopBackOff --wait=false

# Delete evicted pods
echo "Deleting evicted pods..."
kubectl get pods --all-namespaces | grep Evicted | awk '{print $1 " -n " $2}' | xargs -n 3 kubectl delete pod --wait=false

echo "Cleanup completed!"