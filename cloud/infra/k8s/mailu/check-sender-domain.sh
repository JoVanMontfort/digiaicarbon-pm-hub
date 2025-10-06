#!/bin/bash
NAMESPACE="mailcow"
POD="postfix-mail-7db6646f7f-vhsfm"

echo "🔍 Checking Sender Domain Configuration"
echo "======================================"

kubectl -n $NAMESPACE exec -it $POD -- sh -c "
echo '1. Current Postfix domain settings:'
postconf myhostname
postconf mydomain
postconf myorigin

echo ''
echo '2. Recent sent emails and their FROM addresses:'
tail -50 /var/log/syslog 2>/dev/null | grep -E 'from=.*@' | sed 's/.*from=//' | cut -d',' -f1 | sort -u

echo ''
echo '3. The problem might be:'
echo '   - We'\''re sending from root@triggeriq.eu'
echo '   - But triggeriq.eu might not be verified in TEM'
echo '   - TEM might be rejecting emails from unverified domains'
"