#!/bin/bash

echo "🔧 Debugging Network & Firewall Issues"
echo "======================================"

SMTP_IP="51.158.216.249"
IMAP_IP="51.15.102.121"

echo ""
echo "1. Checking LoadBalancer Status..."
kubectl get svc -n mailcow postfix-direct dovecot-direct -o wide

echo ""
echo "2. Testing Raw Network Connectivity..."
echo "   SMTP IP ($SMTP_IP):"
ping -c 2 -W 1 $SMTP_IP && echo "   ✅ Ping - SUCCESS" || echo "   ❌ Ping - FAILED"

echo "   IMAP IP ($IMAP_IP):"
ping -c 2 -W 1 $IMAP_IP && echo "   ✅ Ping - SUCCESS" || echo "   ❌ Ping - FAILED"

echo ""
echo "3. Testing Port Access from Different Locations..."
echo "   From your local machine:"
echo "   SMTP Port 25:"
timeout 3 telnet $SMTP_IP 25 2>&1 | grep -E "(Connected|refused|timeout)" || echo "   Unknown status"

echo "   From inside the cluster:"
kubectl run -it --rm --image=alpine network-test-$(date +%s) -- sh -c "
echo 'Testing SMTP from inside cluster...'
timeout 3 telnet $SMTP_IP 25
echo 'Testing IMAP from inside cluster...'
timeout 3 telnet $IMAP_IP 993
" 2>/dev/null

echo ""
echo "4. Checking LoadBalancer Events..."
kubectl describe svc -n mailcow postfix-direct dovecot-direct | grep -A 10 Events

echo ""
echo "5. Checking Scaleway LoadBalancer Status..."
echo "   Visit: https://console.scaleway.com/load-balancer"
echo "   Check if LoadBalancers are active and healthy"

echo ""
echo "6. Testing Service Internally..."
echo "   SMTP Service ClusterIP:"
SMTP_CLUSTER_IP=$(kubectl get svc postfix-direct -n mailcow -o jsonpath='{.spec.clusterIP}')
echo "   Cluster IP: $SMTP_CLUSTER_IP"
kubectl exec -it deployment/postfix-mail -n mailcow -- telnet $SMTP_CLUSTER_IP 25 <<< QUIT 2>/dev/null && echo "   ✅ Internal connection - SUCCESS" || echo "   ❌ Internal connection - FAILED"