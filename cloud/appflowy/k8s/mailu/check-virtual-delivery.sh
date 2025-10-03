#!/bin/bash

echo "🔍 Checking Virtual Mailbox Delivery"

echo ""
echo "1. Testing virtual map lookup..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
for user in test admin jo amanda; do
    echo -n "$user@damno-solutions.be -> "
    postmap -q "$user@damno-solutions.be" hash:/etc/postfix/virtual 2>&1
done
'

echo ""
echo "2. Checking virtual mailbox directories..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "Mail directory structure:"
find /var/mail/ -type d -exec ls -ld {} \; 2>/dev/null

echo "Mail files:"
find /var/mail/ -type f -exec ls -la {} \; 2>/dev/null
'

echo ""
echo "3. Testing local delivery with Postfix..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "Testing local delivery mechanism..."
echo "This is a test" | sendmail -v test@damno-solutions.be 2>&1 | head -10
'

echo ""
echo "4. Checking recent Postfix logs for virtual delivery..."
kubectl logs deployment/postfix-mail -n mailcow --tail=30 | grep -E "(virtual|local)" | tail -10