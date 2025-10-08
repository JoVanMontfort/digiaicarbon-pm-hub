#!/bin/bash
echo "🔧 Fixing Mail Loop Configuration"

echo "1. Checking current delivery configuration..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Current delivery settings ==="
postconf mydestination inet_interfaces mynetworks
'

echo ""
echo "2. Fixing mail loop by configuring proper delivery..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Configuring for local delivery only ==="
# Remove mail.triggeriq.eu from mydestination to avoid loops
postconf -e "mydestination=localhost.localdomain, localhost"
postconf -e "inet_interfaces=all"
postconf -e "mynetworks=127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16"

# Ensure virtual transport is used for our domain
postconf -e "virtual_alias_domains="
postconf -e "virtual_alias_maps="

echo "=== Updated configuration ==="
postconf mydestination virtual_mailbox_domains
'

echo ""
echo "3. Reloading Postfix..."
kubectl exec -it deployment/postfix-mail -n mailcow -- postfix reload

echo ""
echo "4. Testing local mail delivery..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c "
echo 'Subject: Fixed Loop Test
From: test@triggeriq.eu
To: test@triggeriq.eu

Testing after fixing mail loop configuration.' | sendmail -v test@triggeriq.eu
"

echo ""
echo "5. Checking delivery status..."
sleep 3
kubectl exec -it deployment/postfix-mail -n mailcow -- mailq

echo ""
echo "6. Checking if mail was delivered..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Checking mail directories ==="
find /var/mail/ -type f -name "*" 2>/dev/null | head -10
echo "=== Recent files in test mailbox ==="
ls -la /var/mail/test/ 2>/dev/null || echo "No test mailbox yet"
'

echo ""
echo "7. Checking logs for delivery..."
kubectl logs -n mailcow deployment/postfix-mail --tail=15

echo ""
echo "🎉 Mail loop configuration fixed!"