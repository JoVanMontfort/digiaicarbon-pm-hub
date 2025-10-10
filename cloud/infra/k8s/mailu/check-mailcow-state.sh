#!/bin/bash

echo "🔍 Checking Mailcow's Current State"
echo "=================================="

NAMESPACE="mailcow"

echo ""
echo "1. Checking if triggeriq.eu is in Mailcow..."
kubectl exec -n $NAMESPACE postgresql-0 -- psql -U mailcow -d mailcow -c "SELECT * FROM domain WHERE domain = 'triggeriq.eu';"

echo ""
echo "2. Checking existing Mailcow users..."
kubectl exec -n $NAMESPACE postgresql-0 -- psql -U mailcow -d mailcow -c "SELECT username, active FROM mailbox LIMIT 10;"

echo ""
echo "3. Checking Mailcow admin access..."
kubectl get svc -n $NAMESPACE | grep nginx