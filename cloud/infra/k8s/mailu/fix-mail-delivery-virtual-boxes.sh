#!/bin/bash

echo "🔧 Fixing Email Delivery to Virtual Mailboxes"
echo "============================================"

NAMESPACE="mailcow"
POSTFIX_POD="postfix-mail-665dc57ccf-fd7ml"

echo ""
echo "1. Checking Postfix Virtual Configuration..."
echo "------------------------------------------"

kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c '
echo "=== Current virtual settings ==="
postconf virtual_mailbox_domains virtual_mailbox_maps virtual_mailbox_base virtual_transport

echo ""
echo "=== Setting correct virtual configuration ==="
postconf -e "virtual_mailbox_domains=triggeriq.eu"
postconf -e "virtual_mailbox_maps=hash:/etc/postfix/virtual"
postconf -e "virtual_mailbox_base=/var/mail"
postconf -e "virtual_transport=virtual"
postconf -e "virtual_uid_maps=static:5000"
postconf -e "virtual_gid_maps=static:5000"

echo ""
echo "=== Updated configuration ==="
postconf virtual_mailbox_domains virtual_mailbox_maps virtual_transport
'

echo ""
echo "2. Checking Mail Queue Details..."
echo "-------------------------------"

kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c '
echo "=== Detailed mail queue ==="
postqueue -p

echo ""
echo "=== Trying to flush queue ==="
postqueue -f
sleep 2
postqueue -p
'

echo ""
echo "3. Checking Postfix Logs for Errors..."
echo "------------------------------------"

kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c '
echo "=== Recent Postfix logs ==="
tail -30 /var/log/mail.log 2>/dev/null | grep -E "(support@|virtual|error|fatal|reject)" || echo "No mail.log file, checking syslog..."
tail -30 /var/log/syslog 2>/dev/null | grep -E "(support@|virtual|error|fatal|reject)" || echo "No relevant logs found"
'

echo ""
echo "4. Testing Virtual Delivery Directly..."
echo "-------------------------------------"

kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c '
echo "=== Testing virtual delivery service ==="
ls -la /usr/lib/postfix/sbin/virtual 2>/dev/null || echo "Virtual transport not found"

echo ""
echo "=== Manual delivery test ==="
echo "From: test@triggeriq.eu" > /tmp/test_email
echo "To: support@triggeriq.eu" >> /tmp/test_email
echo "Subject: Manual Test" >> /tmp/test_email
echo "" >> /tmp/test_email
echo "Testing manual delivery" >> /tmp/test_email

postmap -q "support@triggeriq.eu" hash:/etc/postfix/virtual
echo "Virtual map result: $?"
'

echo ""
echo "5. Checking Directory Permissions..."
echo "----------------------------------"

kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c '
echo "=== Mail directory permissions ==="
ls -la /var/mail/
echo ""
echo "=== Support directory permissions ==="
ls -la /var/mail/support/
echo ""
echo "=== Support Maildir permissions ==="
ls -la /var/mail/support/Maildir/
'

echo ""
echo "6. Reloading Postfix and Testing Again..."
echo "---------------------------------------"

kubectl exec -n $NAMESPACE $POSTFIX_POD -- postfix reload
sleep 3

echo ""
echo "7. Testing Fresh Email Delivery..."
echo "--------------------------------"

kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c "
echo 'Testing fresh email delivery...'
echo 'Subject: FRESH TEST - Virtual Delivery
From: test@triggeriq.eu
To: support@triggeriq.eu

This is a fresh test after fixing virtual configuration.' | sendmail -v support@triggeriq.eu
"

echo ""
echo "8. Checking Results..."
echo "--------------------"
sleep 5

kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c '
echo "=== Mail queue status ==="
postqueue -p

echo ""
echo "=== Support mailbox contents ==="
find /var/mail/support -type f 2>/dev/null
echo ""
echo "Email count: $(find /var/mail/support -type f 2>/dev/null | wc -l)"

echo ""
echo "=== Checking delivery in logs ==="
tail -20 /var/log/mail.log 2>/dev/null | tail -5
'

echo ""
echo "9. Configuring Dovecot for Support Mailbox Access..."
echo "--------------------------------------------------"

DOVECOT_POD="dovecot-mail-79b96d4cf4-s98vr"

kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "=== Current Dovecot status ==="
if [ -f /run/dovecot/master.pid ]; then
    echo "Dovecot is running with PID: $(cat /run/dovecot/master.pid)"
    echo "Stopping Dovecot..."
    kill $(cat /run/dovecot/master.pid)
    sleep 3
fi

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
echo "=== Checking Dovecot ==="
if [ -f /run/dovecot/master.pid ]; then
    echo "✅ Dovecot running with PID: $(cat /run/dovecot/master.pid)"
else
    echo "❌ Dovecot not running, checking process..."
    ps aux | grep dovecot | grep -v grep || echo "No dovecot process found"
fi
'

echo ""
echo "🎯 FINAL THUNDERBIRD TEST:"
echo "========================"
echo "IMAP: 51.15.102.121:143"
echo "User: support@triggeriq.eu"
echo "Pass: support123"
echo ""
echo "Even if no emails delivered yet, you should be able to:"
echo "1. Connect to IMAP"
echo "2. See empty support mailbox"
echo "3. Send test emails that should appear"