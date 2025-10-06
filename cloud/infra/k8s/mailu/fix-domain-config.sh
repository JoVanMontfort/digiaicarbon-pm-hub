#!/bin/bash
NAMESPACE="mailcow"
POD="postfix-mail-7db6646f7f-vhsfm"

echo "🔧 Fixing Domain Configuration for triggeriq.eu"
echo "=============================================="

kubectl -n $NAMESPACE exec -it $POD -- sh -c "
echo '1. Current domain settings causing mismatch:'
echo '   myhostname: ' && postconf myhostname
echo '   mydomain: ' && postconf mydomain
echo '   myorigin: ' && postconf myorigin

echo ''
echo '2. Reconfiguring for triggeriq.eu...'
postconf -e 'myhostname = mail.triggeriq.eu'
postconf -e 'mydomain = triggeriq.eu'
postconf -e 'myorigin = \$mydomain'

echo ''
echo '3. Removing generic maps if they exist...'
postconf -X smtp_generic_maps 2>/dev/null || true
rm -f /etc/postfix/generic /etc/postfix/generic.db 2>/dev/null || true

echo ''
echo '4. Reloading Postfix...'
postfix reload

echo ''
echo '5. New domain configuration:'
postconf myhostname
postconf mydomain
postconf myorigin

echo ''
echo '6. Testing with proper triggeriq.eu domain...'
echo 'Subject: Fixed Domain Test - triggeriq.eu
From: test@triggeriq.eu
To: jovm007me@gmail.com

Now using proper triggeriq.eu domain configuration.

This should work if triggeriq.eu is verified in TEM.' | sendmail -t

sleep 5
echo ''
echo '7. Queue status:'
postqueue -p
"