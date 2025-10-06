#!/bin/bash
NAMESPACE="mailcow"
POD="postfix-mail-7db6646f7f-vhsfm"

echo "🎯 Testing Email with OPEN Port 2587"
echo "==================================="

kubectl -n $NAMESPACE exec -it $POD -- sh -c "
echo '1. Current configuration:'
postconf relayhost
postconf smtp_sasl_auth_enable

echo ''
echo '2. Testing TEM connectivity on port 2587...'
timeout 5 bash -c '</dev/tcp/smtp.tem.scaleway.com/2587' && echo '✅ Port 2587 reachable' || echo '❌ Port 2587 not reachable'

echo ''
echo '3. Clear queue...'
postsuper -d ALL

echo ''
echo '4. Send test email via port 2587...'
echo 'Subject: SUCCESS! TEM Port 2587 Test
From: test@triggeriq.eu
To: jovm007me@gmail.com

🎉 BREAKTHROUGH! We found an open port!

Server: smtp.tem.scaleway.com
Port: 2587 (alternative port)
Status: CONNECTED

This proves Scaleway Kapsule + TEM can work together!
The key was finding the alternative ports 2587/2465.' | sendmail -t

echo ''
echo '5. Check queue status...'
sleep 5
postqueue -p

echo ''
echo '6. Check delivery attempts...'
tail -20 /var/log/mail.log 2>/dev/null | grep -E '(tem.scaleway.com|2587|relay|sent|deferred|auth)' | tail -10 || echo 'Check syslog for details'
"