#!/bin/bash
NAMESPACE="mailcow"
POD=$(kubectl get pods -n mailcow -l app=postfix-mail -o jsonpath='{.items[0].metadata.name}')

echo "🔐 Updating Scaleway TEM Credentials"
echo "===================================="

# Get credentials from user
read -p "Enter Scaleway TEM Username: " TEM_USER
read -s -p "Enter Scaleway TEM Password: " TEM_PASS
echo ""

echo ""
echo "🔄 Updating TEM credentials for pod: $POD"
echo "Using IP: 51.159.84.239:2587"

kubectl -n $NAMESPACE exec -it $POD -- sh -c "
echo '1. Creating SASL credentials...'
echo '[51.159.84.239]:2587 ${TEM_USER}:${TEM_PASS}' > /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd
chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.lmdb

echo ''
echo '2. Configuring Postfix...'
postconf -e 'smtp_address_preference = ipv4'
postconf -e 'relayhost = [51.159.84.239]:2587'

echo ''
echo '3. Reloading Postfix...'
postfix reload

echo ''
echo '✅ TEM credentials updated with correct IP!'
"

echo ""
echo "✅ Configuration updated successfully!"
echo "📧 Pod: $POD"
echo "🔗 Next step: Test with: ./test-correct-ip.sh"