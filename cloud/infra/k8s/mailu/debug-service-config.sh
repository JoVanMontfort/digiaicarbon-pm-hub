#!/bin/bash

echo "🔧 Debugging Service Configuration Issues"
echo "========================================="

echo ""
echo "1. Checking Postfix Container Status..."
kubectl logs deployment/postfix-mail -n mailcow --tail=10

echo ""
echo "2. Checking Dovecot Container Status..."
kubectl logs deployment/dovecot-mail -n mailcow --tail=10

echo ""
echo "3. Testing Services Directly on Pods..."
POSTFIX_POD=$(kubectl get pods -n mailcow -l app=postfix-mail -o jsonpath='{.items[0].metadata.name}')
DOVECOT_POD=$(kubectl get pods -n mailcow -l app=dovecot-mail -o jsonpath='{.items[0].metadata.name}')

echo "   Testing Postfix on pod $POSTFIX_POD:"
kubectl exec -it $POSTFIX_POD -n mailcow -- netstat -tlnp | grep :25 || echo "   ❌ Postfix not listening on port 25"

echo "   Testing Dovecot on pod $DOVECOT_POD:"
kubectl exec -it $DOVECOT_POD -n mailcow -- netstat -tlnp | grep :993 || echo "   ❌ Dovecot not listening on port 993"

echo ""
echo "4. Checking Container Processes..."
echo "   Postfix processes:"
kubectl exec -it $POSTFIX_POD -n mailcow -- ps aux | grep postfix

echo "   Dovecot processes:"
kubectl exec -it $DOVECOT_POD -n mailcow -- ps aux | grep dovecot

echo ""
echo "5. Testing Local Connection in Containers..."
echo "   Postfix local test:"
kubectl exec -it $POSTFIX_POD -n mailcow -- telnet localhost 25 <<< QUIT 2>/dev/null && echo "   ✅ Postfix accepts local connections" || echo "   ❌ Postfix rejects local connections"

echo "   Dovecot local test:"
kubectl exec -it $DOVECOT_POD -n mailcow -- telnet localhost 993 <<< QUIT 2>/dev/null && echo "   ✅ Dovecot accepts local connections" || echo "   ❌ Dovecot rejects local connections"