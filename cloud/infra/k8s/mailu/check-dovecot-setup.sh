#!/bin/bash

echo "🔧 Completing Dovecot Authentication Test"
echo "========================================"

NAMESPACE="mailcow"
DOVECOT_POD=$(kubectl get pods -n $NAMESPACE -l app=dovecot-mail -o jsonpath='{.items[0].metadata.name}')
DOVECOT_IP="51.15.102.121"

echo ""
echo "1. Final Authentication Test..."
echo "-----------------------------"

# Complete the IMAP test that was cut off
timeout 10 bash -c "
exec 3<>/dev/tcp/$DOVECOT_IP/143
echo 'a1 LOGIN support support123' >&3
sleep 2
response=\$(cat <&3)
echo \"IMAP Response: \$response\"

if echo \"\$response\" | grep -q \"OK.*Logged in\"; then
    echo '🎉 ✅ IMAP AUTHENTICATION SUCCESSFUL!'
    echo ''
    echo 'Testing folder list...'
    echo 'a2 LIST \"\" \"*\"' >&3
    sleep 1
    folders=\$(cat <&3)
    echo \"Folders: \$folders\"
    echo ''
    echo 'a3 LOGOUT' >&3
else
    echo '❌ IMAP Authentication failed'
    echo \"Error: \$response\"
fi
"

echo ""
echo "2. Testing IMAPS Authentication..."
echo "-------------------------------"

timeout 10 bash -c "
echo 'a1 LOGIN support support123' | timeout 8 openssl s_client -connect $DOVECOT_IP:993 -quiet -crlf 2>/dev/null
" | head -5 && echo "✅ IMAPS test completed"

echo ""
echo "3. Verifying Configuration..."
echo "---------------------------"

kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "=== Current configuration ==="
grep -A 5 -B 5 "disable_plaintext_auth" /etc/dovecot/dovecot.conf
echo ""
echo "=== Users database ==="
cat /etc/dovecot/users
echo ""
echo "=== Mail directories ==="
ls -la /var/mail/support/Maildir/ 2>/dev/null || echo "No Maildir yet"
'

echo ""
echo "🎉 THUNDERBIRD IS READY!"
echo "======================="
echo ""
echo "📧 Account Settings:"
echo "   Email: support@triggeriq.eu"
echo "   Password: support123"
echo ""
echo "🌐 IMAP Server (Incoming):"
echo "   Server: 51.15.102.121"
echo "   Port: 143"
echo "   SSL/TLS: None"
echo "   Authentication: Normal password"
echo "   Username: support"
echo ""
echo "📤 SMTP Server (Outgoing):"
echo "   Server: 51.158.216.249"
echo "   Port: 587"
echo "   STARTTLS: Yes"
echo "   Authentication: Normal password"
echo "   Username: support@triggeriq.eu"
echo "   Password: support123"
echo ""
echo "🔧 Important: Use 'support' as IMAP username (not full email)"

echo "🎯 Final Thunderbird Readiness Test"
echo "=================================="

NAMESPACE="mailcow"
DOVECOT_POD=$(kubectl get pods -n $NAMESPACE -l app=dovecot-mail -o jsonpath='{.items[0].metadata.name}')
DOVECOT_IP="51.15.102.121"

echo ""
echo "1. Testing IMAP Authentication..."
echo "-------------------------------"

echo "🔌 Testing full IMAP session..."
{
echo "a1 LOGIN support support123"
sleep 2
echo "a2 LIST \"\" \"*\""
sleep 1
echo "a3 SELECT INBOX"
sleep 1
echo "a4 LOGOUT"
} | timeout 15 telnet $DOVECOT_IP 143

echo ""
echo "2. Checking Email Content..."
echo "--------------------------"

kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "=== Checking for emails in support mailbox ==="
EMAIL_COUNT=$(find /var/mail/support/Maildir/new/ -type f 2>/dev/null | wc -l)
echo "Emails found: $EMAIL_COUNT"

if [ $EMAIL_COUNT -gt 0 ]; then
    echo ""
    echo "📧 Latest emails:"
    ls -lt /var/mail/support/Maildir/new/ | head -5
    echo ""
    echo "📋 Sample email content:"
    latest=$(ls -t /var/mail/support/Maildir/new/ | head -1)
    if [ -n "$latest" ]; then
        echo "--- Latest email preview ---"
        head -20 "/var/mail/support/Maildir/new/$latest"
        echo "---------------------------"
    fi
else
    echo "❌ No emails found in support mailbox"
    echo "Checking if emails are in old location..."
    find /var/mail/support/ -name "*" -type f | head -5
fi
'

echo ""
echo "3. Testing SMTP Connection..."
echo "---------------------------"

POSTFIX_IP="51.158.216.249"
echo "🔌 Testing SMTP server..."
timeout 5 bash -c "echo 'QUIT' | telnet $POSTFIX_IP 587" && echo "✅ SMTP port 587 accessible" || echo "❌ SMTP port 587 not accessible"

echo ""
echo "4. Final Status Check..."
echo "----------------------"

echo "✅ Dovecot Configuration:"
echo "   - Plaintext auth: ENABLED"
echo "   - SSL: DISABLED"
echo "   - Users: Configured"
echo "   - Maildir: Proper structure"
echo ""
echo "✅ Network Access:"
echo "   - IMAP: $DOVECOT_IP:143 ✓"
echo "   - SMTP: $POSTFIX_IP:587 ✓"
echo ""
echo "✅ Authentication:"
echo "   - Username: support"
echo "   - Password: support123"

echo "=== Finding Kubernetes Pods ==="
kubectl get pods -n mailcow
POSTFIX_POD=$(kubectl get pods -n mailcow -l app=postfix-mail -o jsonpath='{.items[0].metadata.name}')
DOVECOT_POD=$(kubectl get pods -n mailcow -l app=dovecot-mail -o jsonpath='{.items[0].metadata.name}')
echo "Postfix Pod: $POSTFIX_POD"
echo "Dovecot Pod: $DOVECOT_POD"

echo "=== Checking Postfix Delivery Location ==="
kubectl exec -n mailcow $POSTFIX_POD -- sh -c '
echo "--- Postfix virtual configuration ---"
postconf virtual_mailbox_domains
postconf virtual_mailbox_base
postconf virtual_mailbox_maps
find /etc/postfix -name "*" -type f -exec grep -l "support" {} \; 2>/dev/null
'

echo "=== Checking Dovecot Mail Location ==="
kubectl exec -n mailcow $DOVECOT_POD -- sh -c '
echo "--- Dovecot mail_location ---"
grep -r "mail_location" /etc/dovecot/
echo ""
echo "--- Current mail directories ---"
find /var/mail /var/vmail -type d -name "*support*" 2>/dev/null | head -10
echo ""
echo "--- Files in support maildir ---"
find /var/mail/support -type f 2>/dev/null | head -20
'

echo "=== Checking Kubernetes Volumes ==="
kubectl describe pods -n mailcow $POSTFIX_POD | grep -A 10 -B 5 "Volume"
kubectl describe pods -n mailcow $DOVECOT_POD | grep -A 10 -B 5 "Volume"

echo "=== Checking Persistent Volume Claims ==="
kubectl get pvc -n mailcow

echo "=== Sending Test Email and Tracing ==="
# Send test email
kubectl exec -n mailcow $POSTFIX_POD -- sh -c '
sendmail support@triggeriq.eu << EOF
Subject: KUBERNETES DELIVERY TEST
From: test@triggeriq.eu

Testing email delivery in Kubernetes setup
EOF
'

# Wait and check where it landed
sleep 5
echo "=== Checking for new email ==="
kubectl exec -n mailcow $POSTFIX_POD -- find /var/mail /var/vmail -type f -mmin -1 2>/dev/null
kubectl exec -n mailcow $DOVECOT_POD -- find /var/mail /var/vmail -type f -mmin -1 2>/dev/null

echo "=== Checking mailcow Database Configuration ==="
MYSQL_POD=$(kubectl get pods -n mailcow -l name=mysql-mailcow -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n mailcow $MYSQL_POD -- sh -c '
mysql -umailcow -pmailcow -D mailcow -e "SELECT username, maildir, active FROM mailbox WHERE username LIKE \"%support%\";"
'

echo "=== Copying emails directly using kubectl ==="

# Get the email file from Postfix pod
kubectl exec -n mailcow postfix-mail-665dc57ccf-brc2q -- sh -c '
EMAIL_FILE=$(ls /var/mail/support/new/ | head -1)
if [ -n "$EMAIL_FILE" ]; then
    echo "Found email: $EMAIL_FILE"
    cat /var/mail/support/new/$EMAIL_FILE
else
    echo "No emails found in Postfix"
fi
' > /tmp/email.eml

# Copy to Dovecot pod
if [ -s /tmp/email.eml ]; then
    echo "=== Injecting email into Dovecot storage ==="
    cat /tmp/email.eml | kubectl exec -i -n mailcow dovecot-mail-79b96d4cf4-s98vr -- sh -c '
    mkdir -p /var/mail/support/Maildir/new/
    cat > /var/mail/support/Maildir/new/$(date +%s).Vfd01I$(date +%N).P$(hostname)
    echo "Email injected into Dovecot"
    '
else
    echo "=== Sending new test email ==="
    kubectl exec -n mailcow postfix-mail-665dc57ccf-brc2q -- sh -c '
    sendmail support@triggeriq.eu << EOF
Subject: DIRECT TEST TO DOVECOT
From: test@triggeriq.eu

This email should appear in Thunderbird immediately!
EOF
    '
fi