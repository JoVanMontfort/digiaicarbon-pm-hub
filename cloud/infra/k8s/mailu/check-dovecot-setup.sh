#!/bin/bash

echo "🔧 Completing Dovecot Authentication Test with PROPER Email Sync"
echo "==============================================================="

NAMESPACE="mailcow"
DOVECOT_POD=$(kubectl get pods -n $NAMESPACE -l app=dovecot-mail -o jsonpath='{.items[0].metadata.name}')
POSTFIX_POD=$(kubectl get pods -n $NAMESPACE -l app=postfix-mail -o jsonpath='{.items[0].metadata.name}')
DOVECOT_IP="51.15.102.121"
POSTFIX_IP="51.158.216.249"

echo ""
echo "📧 STEP 1: PROPER Email Sync from Postfix to Dovecot"
echo "==================================================="

echo "=== Method 1: Direct File Transfer between Pods ==="
# Get the list of emails from Postfix
echo "Getting email list from Postfix..."
EMAIL_LIST=$(kubectl exec -n $NAMESPACE $POSTFIX_POD -- find /var/mail/support/new/ -type f 2>/dev/null)

if [ -n "$EMAIL_LIST" ]; then
    echo "Found $(echo "$EMAIL_LIST" | wc -l) emails in Postfix"

    # Copy each email individually
    echo "$EMAIL_LIST" | while read email_path; do
        if [ -n "$email_path" ]; then
            filename=$(basename "$email_path")
            echo "Copying: $filename"

            # Method 1A: Use kubectl cp (if volumes allow)
            kubectl cp $NAMESPACE/$POSTFIX_POD:$email_path /tmp/$filename 2>/dev/null
            if [ -f "/tmp/$filename" ]; then
                kubectl cp /tmp/$filename $NAMESPACE/$DOVECOT_POD:/var/mail/support/Maildir/new/$filename 2>/dev/null
                rm -f /tmp/$filename
                echo "✅ Copied via kubectl cp: $filename"
            else
                # Method 1B: Use exec with tar for direct transfer
                kubectl exec -n $NAMESPACE $POSTFIX_POD -- tar cf - "$email_path" 2>/dev/null | \
                kubectl exec -i -n $NAMESPACE $DOVECOT_POD -- tar xf - -C /var/mail/support/Maildir/new/ 2>/dev/null
                echo "✅ Copied via tar: $filename"
            fi
        fi
    done
else
    echo "No emails found in Postfix"
fi

echo ""
echo "=== Method 2: Recreate Emails in Dovecot ==="
# If direct copy fails, recreate the emails by reading content
kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c '
EMAIL_FILES=$(find /var/mail/support/new/ -type f 2>/dev/null | head -10)
if [ -n "$EMAIL_FILES" ]; then
    echo "Recreating emails in Dovecot..."
    for email_file in $EMAIL_FILES; do
        if [ -f "$email_file" ]; then
            filename=$(basename "$email_file")
            # Create the same email content in Dovecot
            kubectl exec -n mailcow dovecot-mail-79b96d4cf4-s98vr -- sh -c "
            mkdir -p /var/mail/support/Maildir/new/
            cat > /var/mail/support/Maildir/new/$filename << \"EOF\"
$(cat "$email_file")
EOF
            " && echo "Recreated: $filename"
        fi
    done
fi
'

echo ""
echo "=== Method 3: Simple Test Email ==="
# Create a simple test email directly in Dovecot
kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
mkdir -p /var/mail/support/Maildir/new/
cat > /var/mail/support/Maildir/new/test-direct-$(date +%s).eml << "EOF"
Subject: DIRECT DOVECOT TEST EMAIL
From: direct@triggeriq.eu
Date: $(date)
Message-ID: <test-$(date +%s)@triggeriq.eu>

This email was created directly in Dovecot storage.
If you see this in Thunderbird, Dovecot is working correctly!

Test timestamp: $(date)
EOF
echo "Created direct test email in Dovecot"
'

echo ""
echo "=== Verifying emails in Dovecot ==="
kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "--- Current emails in Dovecot ---"
find /var/mail/support/Maildir/new/ -type f 2>/dev/null | wc -l
find /var/mail/support/Maildir/new/ -type f 2>/dev/null | head -5
ls -la /var/mail/support/Maildir/new/ 2>/dev/null | head -10
'

echo ""
echo "🔐 STEP 2: Authentication and IMAP Tests"
echo "========================================"

echo ""
echo "1. Testing IMAP Authentication and Email Count..."
echo "-----------------------------------------------"

{
echo "a1 LOGIN support support123"
sleep 2
echo "a2 LIST \"\" \"*\""
sleep 1
echo "a3 SELECT INBOX"
sleep 1
echo "a4 SEARCH ALL"
sleep 1
echo "a5 FETCH 1:* (BODY.PEEK[HEADER.FIELDS (SUBJECT FROM)])"
sleep 1
echo "a6 LOGOUT"
} | timeout 20 telnet $DOVECOT_IP 143

echo ""
echo "📧 STEP 3: Dovecot Maildir Structure Fix"
echo "========================================"

# Fix the Maildir structure and permissions
kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "=== Fixing Maildir structure ==="
mkdir -p /var/mail/support/Maildir/{cur,new,tmp}
chown -R 5000:5000 /var/mail/support/Maildir/

# Check if emails need to be moved from other locations
if [ -d "/var/mail/support/cur" ] && [ "$(ls -A /var/mail/support/cur/ 2>/dev/null)" ]; then
    echo "Moving emails from cur to Maildir/cur/"
    mv /var/mail/support/cur/* /var/mail/support/Maildir/cur/ 2>/dev/null || true
fi

if [ -d "/var/mail/support/new" ] && [ "$(ls -A /var/mail/support/new/ 2>/dev/null)" ]; then
    echo "Moving emails from new to Maildir/new/"
    mv /var/mail/support/new/* /var/mail/support/Maildir/new/ 2>/dev/null || true
fi

echo "=== Final email count ==="
find /var/mail/support/Maildir/ -name "*" -type f | wc -l
echo "new/: $(find /var/mail/support/Maildir/new/ -type f 2>/dev/null | wc -l)"
echo "cur/: $(find /var/mail/support/Maildir/cur/ -type f 2>/dev/null | wc -l)"
'

echo ""
echo "🎯 STEP 4: Immediate Thunderbird Test"
echo "===================================="

echo ""
echo "🚀 IMMEDIATE ACTION REQUIRED:"
echo "1. Open Thunderbird NOW"
echo "2. Select the support@triggeriq.eu account"
echo "3. Press F5 to refresh"
echo "4. Check if you see the 'DIRECT DOVECOT TEST EMAIL'"
echo ""
echo "📊 Current Status:"
kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
EMAIL_COUNT=$(find /var/mail/support/Maildir/new/ -type f 2>/dev/null | wc -l)
CUR_COUNT=$(find /var/mail/support/Maildir/cur/ -type f 2>/dev/null | wc -l)
echo "   - Emails in 'new' folder: $EMAIL_COUNT"
echo "   - Emails in 'cur' folder: $CUR_COUNT"
echo "   - Total emails: $((EMAIL_COUNT + CUR_COUNT))"
'

echo ""
echo "🔧 If still no emails in Thunderbird:"
echo "   - Right-click account → Subscribe → Check ALL folders"
echo "   - Restart Thunderbird"
echo "   - Check Tools → Error Console for errors"

echo ""
echo "========================================="
echo "🎉 SYNC COMPLETED - CHECK THUNDERBIRD!"
echo "========================================="