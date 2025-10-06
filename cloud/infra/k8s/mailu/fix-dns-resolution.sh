#!/bin/bash
NAMESPACE="mailcow"
POD="postfix-mail-7db6646f7f-vhsfm"

echo "🔧 Fixing DNS Resolution in Kubernetes Pod"
echo "========================================="

kubectl -n $NAMESPACE exec -it $POD -- sh -c "
echo '1. Check current DNS configuration...'
cat /etc/resolv.conf

echo ''
echo '2. Test basic DNS resolution...'
echo 'Testing Google DNS:'
nslookup google.com 8.8.8.8 2>/dev/null || echo 'nslookup not available'

echo ''
echo '3. Test using getent:'
getent hosts google.com || echo 'getent failed'

echo ''
echo '4. Test basic connectivity:'
ping -c 2 8.8.8.8 2>/dev/null && echo '✅ Basic network connectivity OK' || echo '❌ Network connectivity issues'

echo ''
echo '5. Check if we can resolve ANY external domains:'
for domain in google.com scaleway.com cloudflare.com; do
    if getent hosts \$domain >/dev/null 2>&1; then
        echo \"✅ \$domain resolvable\"
    else
        echo \"❌ \$domain not resolvable\"
    fi
done

echo ''
echo '6. Manual test for Scaleway TEM:'
getent hosts smtp-relay.scaleway.com || echo 'Cannot resolve smtp-relay.scaleway.com'
"