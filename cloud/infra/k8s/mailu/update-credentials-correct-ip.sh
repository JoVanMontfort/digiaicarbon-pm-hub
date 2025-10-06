#!/bin/bash
NAMESPACE="mailcow"
POD="postfix-mail-7db6646f7f-vhsfm"

read -p "Enter Scaleway TEM Username: " TEM_USER
read -s -p "Enter Scaleway TEM Password: " TEM_PASS
echo ""

echo "Updating TEM credentials with correct IP..."
kubectl -n $NAMESPACE exec -it $POD -- sh -c "
echo '[51.159.84.239]:2587 ${TEM_USER}:${TEM_PASS}' > /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd
chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.lmdb
postconf -e 'smtp_address_preference = ipv4'
postconf -e 'relayhost = [51.159.84.239]:2587'
postfix reload
echo '✅ TEM credentials updated with correct IP!'
"

echo ""
echo "✅ Configuration updated!"
echo "Now test with: ./test-correct-ip.sh"