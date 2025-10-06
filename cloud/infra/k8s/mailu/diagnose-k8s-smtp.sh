#!/bin/bash
NAMESPACE="mailcow"
POD="postfix-mail-7db6646f7f-vhsfm"

echo "🔧 Kubernetes SMTP Diagnostics"
echo "=============================="
echo "Namespace: $NAMESPACE"
echo "Pod: $POD"
echo ""

echo "1. Testing outbound connectivity from pod:"
kubectl -n $NAMESPACE exec -it $POD -- telnet alt2.gmail-smtp-in.l.google.com 25

echo ""
echo "2. Checking Kubernetes network policies:"
kubectl -n $NAMESPACE get networkpolicies

echo ""
echo "3. Checking pod network configuration:"
kubectl -n $NAMESPACE describe pod $POD

echo ""
echo "4. Testing DNS resolution from pod:"
kubectl -n $NAMESPACE exec -it $POD -- nslookup gmail-smtp-in.l.google.com

echo ""
echo "5. Check pod environment:"
kubectl -n $NAMESPACE exec -it $POD -- env | grep -i postfix