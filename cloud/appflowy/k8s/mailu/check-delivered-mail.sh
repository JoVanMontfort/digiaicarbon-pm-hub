#!/bin/bash

echo "📧 Checking Delivered Mail"
echo "=========================="

echo ""
echo "1. Checking Postfix logs for recent deliveries..."
kubectl logs deployment/postfix-mail -n mailcow --since=10m | grep -E "(delivered|status=|from=<|to=<)" | tail -20

echo ""
echo "2. Checking mail queue status..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "Mail queue:"
postqueue -p 2>/dev/null | head -10 || echo "No mail queue output"

echo "Active queue directories:"
find /var/spool/postfix/ -type d -name "active" -exec ls -la {} \; 2>/dev/null
'

echo ""
echo "3. Checking local mail files..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "Mail directories:"
ls -la /var/mail/ 2>/dev/null || echo "No /var/mail directory"

echo "Mail files found:"
find /var/mail/ -type f 2>/dev/null | while read file; do
    echo "File: $file"
    echo "Size: $(stat -c%s "$file" 2>/dev/null || echo "0") bytes"
    echo "First line: $(head -1 "$file" 2>/dev/null | cut -c1-50)"
    echo "---"
done
'

echo ""
echo "4. Testing IMAP access..."
timeout 10 openssl s_client -connect 51.15.102.121:993 -quiet 2>&1 | head -5 && echo "✅ IMAP accessible" || echo "❌ IMAP not accessible"

echo ""
echo "5. Current Postfix virtual configuration:"
kubectl exec -it deployment/postfix-mail -n mailcow -- postconf -n | grep -E "(virtual|mydestination)" | grep -v "^#"

echo ""
echo "🔍 Delivery Status Summary:"
kubectl logs deployment/postfix-mail -n mailcow --tail=100 | grep -o "status=[^ ]*" | sort | uniq -c