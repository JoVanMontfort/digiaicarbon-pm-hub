#!/bin/bash
NAMESPACE="mailcow"
POD="postfix-mail-7db6646f7f-vhsfm"

echo "🔧 Fixing Network Connectivity"
echo "============================="

kubectl -n $NAMESPACE exec -it $POD -- sh -c "
echo '1. Force IPv4 for all SMTP connections...'
postconf -e 'smtp_address_preference = ipv4'
postconf -e 'smtp_bind_address = 0.0.0.0'

echo ''
echo '2. Test basic IPv4 connectivity...'
ping -c 2 8.8.8.8 && echo '✅ IPv4 connectivity OK' || echo '❌ IPv4 connectivity failed'

echo ''
echo '3. Test if we can reach external services...'
echo 'Testing port 587 with IPv4:'
timeout 5 bash -c '</dev/tcp/smtp.strato.com/587' && echo '✅ Port 587 reachable via IPv4' || echo '❌ Port 587 blocked'

echo ''
echo '4. Check current network configuration:'
ip addr show | grep inet
echo ''
ip route show

echo ''
echo '5. If port 587 is blocked, try alternative approaches...'
"