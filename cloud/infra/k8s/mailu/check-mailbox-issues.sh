#!/bin/bash

echo "🔧 Comprehensive Fix for Mail Delivery"
echo "===================================="

NAMESPACE="mailcow"

echo ""
echo "1. Finding Current Pods..."
echo "-------------------------"
kubectl get pods -n $NAMESPACE

echo ""
echo "2. Fixing Postfix Virtual Maps..."
echo "-------------------------------"

POSTFIX_POD=$(kubectl get pods -n $NAMESPACE -l app=postfix-mail -o jsonpath='{.items[0].metadata.name}')
echo "Postfix pod: $POSTFIX_POD"

kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c '
echo "=== Current virtual configuration ==="
postconf virtual_mailbox_maps

echo ""
echo "=== Recompiling virtual maps in correct format ==="
# Remove old LMDB file and compile in hash format
rm -f /etc/postfix/virtual.lmdb
postmap hash:/etc/postfix/virtual

echo ""
echo "=== Checking compiled maps ==="
ls -la /etc/postfix/virtual.*

echo ""
echo "=== Testing virtual map lookup ==="
postmap -q "support@triggeriq.eu" hash:/etc/postfix/virtual
postmap -q "test@triggeriq.eu" hash:/etc/postfix/virtual
'

echo ""
echo "3. Checking Postfix Virtual Configuration..."
echo "------------------------------------------"

kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c '
echo "=== Current virtual settings ==="
postconf virtual_mailbox_domains virtual_mailbox_maps virtual_mailbox_base

echo ""
echo "=== Ensuring virtual transport is set ==="
postconf -e "virtual_transport=virtual"
postconf -e "virtual_mailbox_domains=triggeriq.eu"
postconf -e "virtual_mailbox_maps=hash:/etc/postfix/virtual"
postconf -e "virtual_mailbox_base=/var/mail"
'

echo ""
echo "4. Creating Proper Maildir Structure..."
echo "-------------------------------------"

kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c '
echo "=== Creating proper Maildir structure ==="
for user in support test admin info; do
    echo "Setting up $user..."
    mkdir -p /var/mail/$user/Maildir/{cur,new,tmp}
    chown -R 5000:5000 /var/mail/$user
    # Create a test email file
    echo "From: test@triggeriq.eu" > /var/mail/$user/Maildir/new/test-$(date +%s)
    echo "Subject: Test Email" >> /var/mail/$user/Maildir/new/test-$(date +%s)
    echo "" >> /var/mail/$user/Maildir/new/test-$(date +%s)
    echo "This is a test email for $user" >> /var/mail/$user/Maildir/new/test-$(date +%s)
done

echo ""
echo "=== Final directory structure ==="
ls -la /var/mail/support/Maildir/new/
'

echo ""
echo "5. Reloading Postfix and Testing Delivery..."
echo "------------------------------------------"

kubectl exec -n $NAMESPACE $POSTFIX_POD -- postfix reload
sleep 2

kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c "
echo 'Testing email delivery...'
echo 'Subject: FINAL TEST - Support Mailbox
From: test@triggeriq.eu
To: support@triggeriq.eu

This should now be delivered to the support mailbox!' | sendmail -v support@triggeriq.eu
"

echo ""
echo "6. Checking Delivery Results..."
echo "-----------------------------"
sleep 5

kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c '
echo "=== Mail queue status ==="
mailq

echo ""
echo "=== Support mailbox contents ==="
find /var/mail/support -name "*" -type f 2>/dev/null

echo ""
echo "=== Checking Postfix logs ==="
tail -20 /var/log/mail.log 2>/dev/null | grep -E "(support@|virtual|delivered|bounce)" || echo "No relevant logs in mail.log"
'

echo ""
echo "7. Finding and Configuring Dovecot..."
echo "-----------------------------------"

# Find the current dovecot pod
DOVECOT_POD=$(kubectl get pods -n $NAMESPACE -l app=dovecot-mail -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$DOVECOT_POD" ]; then
    echo "Found Dovecot pod: $DOVECOT_POD"

    kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
    echo "=== Stopping any running Dovecot ==="
    pkill -f dovecot 2>/dev/null
    sleep 2

    echo ""
    echo "=== Creating Dovecot configuration ==="
    mkdir -p /etc/dovecot
    cat > /etc/dovecot/dovecot.conf << EOF
listen = *
protocols = imap
log_path = /dev/stdout
info_log_path = /dev/stdout
ssl = no
auth_mechanisms = plain login
disable_plaintext_auth = no
mail_privileged_group = mail

passdb {
  driver = passwd-file
  args = scheme=plain username_format=%u /etc/dovecot/users
}

userdb {
  driver = passwd-file
  args = username_format=%u /etc/dovecot/users
}

mail_location = maildir:~/Maildir

protocol imap {
  mail_max_userip_connections = 20
}

service imap-login {
  inet_listener imap {
    port = 143
  }
}

service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix
  }
}
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
    echo "=== Starting Dovecot ==="
    dovecot -c /etc/dovecot/dovecot.conf &
    sleep 3

    echo ""
    echo "=== Checking Dovecot status ==="
    if ps aux | grep dovecot | grep -v grep > /dev/null; then
        echo "✅ Dovecot is running"
    else
        echo "❌ Dovecot failed to start"
    fi
    '
else
    echo "❌ No Dovecot pod found - checking services..."
    kubectl get svc -n $NAMESPACE | grep dovecot
fi

echo ""
echo "8. Final Status Check..."
echo "----------------------"
DOVECOT_IP="51.15.102.121"

echo "🔌 Testing IMAP connection..."
timeout 5 bash -c "echo 'QUIT' | telnet $DOVECOT_IP 143" && echo "✅ IMAP port accessible" || echo "❌ IMAP port not accessible"

echo ""
echo "🎯 READY FOR THUNDERBIRD:"
echo "========================"
echo "IMAP: $DOVECOT_IP:143"
echo "User: support@triggeriq.eu"
echo "Pass: support123"
echo "SSL: None"

echo "🔍 Investigating Support Mailbox Issue"
echo "====================================="

echo ""
echo "1. Checking Virtual Mailbox Configuration in Postfix..."
echo "-----------------------------------------------------"

kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c '
echo "=== Virtual mailbox maps ==="
cat /etc/postfix/virtual
echo ""
echo "=== Checking if maps are compiled ==="
ls -la /etc/postfix/virtual.*
echo ""
echo "=== Testing virtual map ==="
postmap -q "support@triggeriq.eu" hash:/etc/postfix/virtual
'

echo ""
echo "2. Checking Where Emails Are Actually Delivered..."
echo "------------------------------------------------"

kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c '
echo "=== Mail directories ==="
find /var/mail -type d 2>/dev/null | head -20
echo ""
echo "=== Support directory contents ==="
if [ -d "/var/mail/support" ]; then
    find /var/mail/support -type f 2>/dev/null | head -10
    echo ""
    echo "Total support emails: $(find /var/mail/support -type f 2>/dev/null | wc -l)"
else
    echo "❌ /var/mail/support directory not found"
    echo "Creating it..."
    mkdir -p /var/mail/support/{cur,new,tmp}
    chown -R 5000:5000 /var/mail/support
fi
'

echo ""
echo "3. Testing Email Delivery to Support..."
echo "-------------------------------------"

kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c "
echo 'Subject: Test Delivery to Support
From: test@triggeriq.eu
To: support@triggeriq.eu

Testing if emails are delivered to support mailbox.' | sendmail -v support@triggeriq.eu
"

echo ""
echo "4. Checking Delivery Results..."
echo "-----------------------------"
sleep 3
kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c '
echo "=== Mail queue ==="
mailq
echo ""
echo "=== Recent logs ==="
tail -10 /var/log/mail.log 2>/dev/null | grep -E "(support@|delivered|bounce)" || echo "No relevant logs found"
'