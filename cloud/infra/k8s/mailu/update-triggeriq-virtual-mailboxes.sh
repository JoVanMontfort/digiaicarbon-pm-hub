#!/bin/bash
echo "🔧 Manually Applying Virtual Mailbox Configuration with LMDB"

echo "1. Checking current state..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Current virtual configuration ==="
postconf virtual_mailbox_domains virtual_mailbox_maps

echo "=== Checking if startup script ran ==="
ls -la /docker-entrypoint.d/ | grep virtual
'

echo ""
echo "2. Manually compiling virtual maps with LMDB..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "Compiling virtual map with LMDB..."
postmap lmdb:/etc/postfix/virtual
echo "=== Checking LMDB files ==="
ls -la /etc/postfix/virtual.lmdb
'

echo ""
echo "3. Manually applying virtual configuration with LMDB..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "Applying virtual mailbox configuration..."
postconf -e "virtual_mailbox_domains=triggeriq.eu"
postconf -e "virtual_mailbox_base=/var/mail"
postconf -e "virtual_mailbox_maps=lmdb:/etc/postfix/virtual"
postconf -e "virtual_uid_maps=static:5000"
postconf -e "virtual_gid_maps=static:5000"
postconf -e "virtual_minimum_uid=5000"
postconf -e "virtual_transport=virtual"
postconf -e "message_size_limit=10240000"
postconf -e "virtual_mailbox_limit=10240000"

# Create mail directories
mkdir -p /var/mail/test /var/mail/admin /var/mail/info /var/mail/support
chown -R 5000:5000 /var/mail

echo "Configuration applied!"
'

echo ""
echo "4. Reloading Postfix..."
kubectl exec -it deployment/postfix-mail -n mailcow -- postfix reload

echo ""
echo "5. Verifying configuration..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Virtual configuration ==="
postconf virtual_mailbox_domains virtual_mailbox_maps

echo "=== Testing virtual map with LMDB ==="
postmap -q "test@triggeriq.eu" lmdb:/etc/postfix/virtual

echo "=== Testing all addresses ==="
for addr in test@triggeriq.eu admin@triggeriq.eu info@triggeriq.eu support@triggeriq.eu; do
    result=$(postmap -q "$addr" lmdb:/etc/postfix/virtual)
    echo "$addr -> $result"
done

echo "=== Mail directories ==="
ls -la /var/mail/
'

echo ""
echo "6. Testing mail delivery..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c "
echo 'Subject: LMDB Configuration Test
From: test@triggeriq.eu
To: test@triggeriq.eu

Testing after manual virtual mailbox configuration with LMDB.' | sendmail -v test@triggeriq.eu
"

echo ""
echo "7. Checking delivery status..."
sleep 3
kubectl exec -it deployment/postfix-mail -n mailcow -- mailq

echo ""
echo "8. Checking logs..."
kubectl logs -n mailcow deployment/postfix-mail --tail=10

echo ""
echo "🎉 Manual virtual mailbox configuration with LMDB applied!"