#!/bin/bash
echo "📬 Checking support@triggeriq.eu Virtual Mailbox"

echo "1. Checking virtual map entry..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Virtual map entry for support@triggeriq.eu ==="
postmap -q "support@triggeriq.eu" lmdb:/etc/postfix/virtual
'

echo ""
echo "2. Checking mail directory..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Support mailbox directory ==="
ls -la /var/mail/support/ 2>/dev/null || echo "Support directory not found"

echo "=== Checking for mail files ==="
find /var/mail/support/ -type f 2>/dev/null | head -10
'

echo ""
echo "3. Testing delivery to support@triggeriq.eu..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c "
echo 'Subject: Test to Support
From: test@triggeriq.eu
To: support@triggeriq.eu

Testing delivery to support mailbox.' | sendmail -v support@triggeriq.eu
"

echo ""
echo "4. Checking delivery status..."
sleep 3
kubectl exec -it deployment/postfix-mail -n mailcow -- mailq

echo ""
echo "5. Verifying support mailbox after test..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Support mailbox contents ==="
ls -la /var/mail/support/new/ 2>/dev/null || echo "No new mail in support mailbox"
'

echo ""
echo "6. Testing from external source to support..."
echo "You can now test sending from Gmail to: support@triggeriq.eu"

echo "📧 Reading Support Mailbox Content"

echo "1. Checking all emails in support mailbox..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== All support emails ==="
ls -lt /var/mail/support/new/ | head -10

echo ""
echo "=== Reading latest support email ==="
latest=$(ls -t /var/mail/support/new/ | head -1)
if [ -n "$latest" ]; then
    echo "File: $latest"
    cat "/var/mail/support/new/$latest"
else
    echo "No emails found"
fi
'

echo ""
echo "2. Checking if any external emails arrived..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Checking for external emails in support ==="
for file in /var/mail/support/new/*; do
    if [ -f "$file" ]; then
        echo "--- $(basename "$file") ---"
        head -5 "$file" | grep -E "(From:|Subject:)" || echo "No headers found"
        echo ""
    fi
done
'

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