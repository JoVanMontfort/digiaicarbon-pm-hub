#!/bin/bash

echo "🧪 Testing Outgoing Mail via Scaleway Relay"
echo "==========================================="

NAMESPACE="mailcow"
POSTFIX_POD=$(kubectl get pods -n mailcow -l app=postfix-mail -o jsonpath='{.items[0].metadata.name}')
EXTERNAL_TEST_EMAIL="jovm007me@gmail.com"  # CHANGE THIS TO YOUR REAL EMAIL

echo ""
echo "1. Checking Current Relay Configuration..."
echo "-----------------------------------------"

echo "🔍 Relay host:"
kubectl exec -n $NAMESPACE $POSTFIX_POD -- postconf relayhost

echo ""
echo "🔍 SASL configuration:"
kubectl exec -n $NAMESPACE $POSTFIX_POD -- ls -la /etc/postfix/sasl/sasl_passwd 2>/dev/null && \
kubectl exec -n $NAMESPACE $POSTFIX_POD -- cat /etc/postfix/sasl/sasl_passwd

echo ""
echo "2. Testing Outgoing to EXTERNAL Domain..."
echo "----------------------------------------"

echo "📤 Sending test to EXTERNAL email: $EXTERNAL_TEST_EMAIL"
kubectl exec -n $NAMESPACE $POSTFIX_POD -- bash -c "
echo 'Subject: SCW Relay Test - External
From: test@triggeriq.eu
To: $EXTERNAL_TEST_EMAIL

This is a test email sent through Scaleway Transactional Email relay.

If successful, you should receive this email.' | sendmail -v $EXTERNAL_TEST_EMAIL
"

echo ""
echo "3. Checking Mail Queue..."
echo "------------------------"
sleep 2
kubectl exec -n $NAMESPACE $POSTFIX_POD -- mailq

echo ""
echo "4. Checking Postfix Logs..."
echo "--------------------------"
echo "📋 Recent log entries:"
kubectl logs -n $NAMESPACE $POSTFIX_POD --tail=20 | grep -E "(relay|SCW|51.159.84.239|sent|deferred|reject)"

echo ""
echo "5. Testing Relay Connectivity..."
echo "-------------------------------"
kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c "
echo 'Testing connection to SCW TEM IP...'
timeout 5 bash -c '</dev/tcp/51.159.84.239/2587' && echo '✅ Port 2587 reachable' || echo '❌ Port 2587 not reachable'
timeout 5 bash -c '</dev/tcp/51.159.84.239/587' && echo '✅ Port 587 reachable' || echo '❌ Port 587 not reachable'
"