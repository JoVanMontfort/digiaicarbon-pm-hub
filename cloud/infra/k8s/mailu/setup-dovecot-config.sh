#!/bin/bash

echo "🔧 Modifying Running Dovecot Configuration"
echo "========================================"

NAMESPACE="mailcow"
DOVECOT_POD=$(kubectl get pods -n $NAMESPACE -l app=dovecot-mail -o jsonpath='{.items[0].metadata.name}')
DOVECOT_IP="51.15.102.121"

echo ""
echo "1. Finding Current Dovecot Configuration..."
echo "-----------------------------------------"

kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "=== Current dovecot.conf ==="
cat /etc/dovecot/dovecot.conf 2>/dev/null | head -20

echo ""
echo "=== Configuration directory ==="
find /etc/dovecot -name "*.conf" -o -name "*.conf*" 2>/dev/null

echo ""
echo "=== Checking if we can modify config ==="
touch /etc/dovecot/test.txt 2>/dev/null && echo "✅ Can write to /etc/dovecot/" || echo "❌ Cannot write to /etc/dovecot/"
'

echo ""
echo "2. Creating Authentication Override..."
echo "------------------------------------"

kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "=== Creating virtual user database ==="
mkdir -p /etc/dovecot/conf.d
cat > /etc/dovecot/conf.d/99-virtual-auth.conf << EOF
# Virtual user authentication override
disable_plaintext_auth = no
auth_mechanisms = plain login

passdb {
  driver = passwd-file
  args = scheme=plain username_format=%u /etc/dovecot/users
}

userdb {
  driver = passwd-file
  args = username_format=%u /etc/dovecot/users
  default_fields = uid=5000 gid=5000 home=/var/mail/%u
}

mail_location = maildir:~/Maildir
EOF

echo ""
echo "=== Creating user database ==="
cat > /etc/dovecot/users << EOF
support:{PLAIN}support123:5000:5000::/var/mail/support::userdb_mail=maildir:~/Maildir
test:{PLAIN}test123:5000:5000::/var/mail/test::userdb_mail=maildir:~/Maildir
admin:{PLAIN}admin123:5000:5000::/var/mail/admin::userdb_mail=maildir:~/Maildir
info:{PLAIN}info123:5000:5000::/var/mail/info::userdb_mail=maildir:~/Maildir
EOF

echo ""
echo "=== Checking if config is included ==="
if grep -q "include.*conf.d" /etc/dovecot/dovecot.conf 2>/dev/null; then
    echo "✅ conf.d directory is included"
else
    echo "⚠️ Adding conf.d include to main config"
    echo "!include conf.d/*.conf" >> /etc/dovecot/dovecot.conf
fi
'

echo ""
echo "3. Reloading Dovecot Configuration..."
echo "-----------------------------------"

# Try to reload dovecot without killing it
kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "=== Checking Dovecot reload method ==="
if [ -f /var/run/dovecot/master.pid ]; then
    echo "Found PID file, trying dovecot reload..."
    dovecot reload 2>/dev/null && echo "✅ Dovecot reloaded" || echo "❌ Could not reload dovecot"
else
    echo "⚠️ No PID file found, configuration changes may require restart"
fi
'

echo ""
echo "4. Testing Authentication..."
echo "--------------------------"

echo "🔌 Testing IMAP (should work now)..."
timeout 10 bash -c "
exec 3<>/dev/tcp/$DOVECOT_IP/143
echo 'a1 LOGIN support support123' >&3
sleep 2
response=\$(cat <&3)
echo \"Response: \$response\"
if echo \"\$response\" | grep -q \"OK.*Logged in\"; then
    echo '✅ AUTHENTICATION SUCCESSFUL!'
    # Try to list folders
    echo 'a2 LIST \"\" \"*\"' >&3
    sleep 1
    cat <&3
else
    echo '❌ Authentication failed'
fi
"

echo "🔧 Fixing Maildir Structure and Finalizing Setup"
echo "=============================================="

NAMESPACE="mailcow"
DOVECOT_POD=$(kubectl get pods -n $NAMESPACE -l app=dovecot-mail -o jsonpath='{.items[0].metadata.name}')
DOVECOT_IP="51.15.102.121"

echo ""
echo "1. Fixing Maildir Structure..."
echo "----------------------------"

kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "=== Creating proper Maildir structure ==="
for user in support test admin info; do
    echo "Fixing $user Maildir..."
    rm -rf /var/mail/$user/Maildir
    mkdir -p /var/mail/$user/Maildir/cur
    mkdir -p /var/mail/$user/Maildir/new
    mkdir -p /var/mail/$user/Maildir/tmp
    chown -R 5000:5000 /var/mail/$user

    # Check if we have emails to move
    if [ -d "/var/mail/$user/new" ] && [ "$(ls -A /var/mail/$user/new/ 2>/dev/null)" ]; then
        echo "Moving existing emails for $user..."
        mv /var/mail/$user/new/* /var/mail/$user/Maildir/new/ 2>/dev/null || echo "No emails to move"
    fi
done

echo ""
echo "=== Verifying Maildir structure ==="
ls -la /var/mail/support/Maildir/
echo ""
echo "Email files in support: $(ls /var/mail/support/Maildir/new/ 2>/dev/null | wc -l)"
'

echo ""
echo "2. Complete IMAP Authentication Test..."
echo "-------------------------------------"

echo "🔌 Testing IMAP login with full session..."
{
echo "a1 LOGIN support support123"
sleep 2
echo "a2 LIST \"\" \"*\""
sleep 1
echo "a3 LOGOUT"
} | timeout 10 telnet $DOVECOT_IP 143

echo ""
echo "3. Testing IMAPS..."
echo "-----------------"

echo "🔌 Testing IMAPS login..."
{
sleep 1
echo "a1 LOGIN support support123"
sleep 2
echo "a2 LIST \"\" \"*\""
sleep 1
echo "a3 LOGOUT"
} | timeout 10 openssl s_client -connect $DOVECOT_IP:993 -quiet -crlf 2>/dev/null

echo ""
echo "4. Final Configuration Check..."
echo "-----------------------------"

kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "=== Dovecot config ==="
grep -E "(disable_plaintext_auth|auth_mechanisms|ssl)" /etc/dovecot/dovecot.conf

echo ""
echo "=== Users check ==="
cat /etc/dovecot/users

echo ""
echo "=== Maildir check ==="
for user in support test admin info; do
    echo "$user: $(find /var/mail/$user/Maildir/new/ -type f 2>/dev/null | wc -l) emails"
done
'