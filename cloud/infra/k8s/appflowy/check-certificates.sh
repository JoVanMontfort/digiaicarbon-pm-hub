#!/bin/bash
echo "=== Certificates ==="
kubectl get certificate -n appflowy
echo -e "\n=== Orders ==="
kubectl get order -n appflowy
echo -e "\n=== Challenges ==="
kubectl get challenge -n appflowy