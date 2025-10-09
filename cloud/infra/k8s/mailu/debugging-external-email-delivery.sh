#!/bin/bash
echo "🔍 Debugging External Email Delivery to support@triggeriq.eu"

echo "1. Checking Postfix logs for external delivery attempts..."
kubectl logs -n mailcow deployment/postfix-mail --tail=50 | grep -E "(support@triggeriq.eu|Gmail|google.com)" | tail -20

echo ""
echo "2. Testing REAL external delivery to support@triggeriq.eu..."
echo "Sending test from command line that simulates external delivery..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c "
echo 'Subject: REAL External Test to Support
From: external-test@gmail.com
To: support@triggeriq.eu

This is a REAL external test to support@triggeriq.eu from Gmail simulation.

If this works, you should see proper email headers with Gmail info.' | sendmail -v -f external-test@gmail.com support@triggeriq.eu
"

echo ""
echo "3. Checking delivery status..."
sleep 5
kubectl exec -it deployment/postfix-mail -n mailcow -- mailq

echo ""
echo "4. Checking support mailbox for the REAL external test..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Latest support email headers ==="
latest=$(ls -t /var/mail/support/new/ | head -1)
if [ -n "$latest" ]; then
    echo "File: $latest"
    head -20 "/var/mail/support/new/$latest"
fi
'

echo ""
echo "5. Real-time log monitoring for external attempts..."
echo "📧 NOW try sending from Gmail to support@triggeriq.eu and watch the logs:"
kubectl logs -n mailcow deployment/postfix-mail --tail=10 --follow

echo "🔧 Checking for any delivery restrictions..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Current restrictions ==="
postconf smtpd_recipient_restrictions
postconf smtpd_sender_restrictions
postconf smtpd_client_restrictions

echo ""
echo "=== Checking for any block lists ==="
ls -la /etc/postfix/ | grep -E "(access|restrict|block)"
'