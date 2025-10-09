#!/bin/bash
NAMESPACE="mailcow"
POD=$(kubectl get pods -n mailcow -l app=postfix-mail -o jsonpath='{.items[0].metadata.name}')
SCW_TEM_IP="51.159.84.239"
SCW_TEM_PORT="2587"

echo "🚀 Configuring Scaleway TEM Relay using IP: $SCW_TEM_IP:$SCW_TEM_PORT"
echo "===================================================================="

# Get credentials from user
read -p "Enter TEM Username: " TEM_USER
read -s -p "Enter API Key: " API_KEY
echo ""

kubectl -n $NAMESPACE exec -it $POD -- sh -c "
echo '1. Testing TEM IP connectivity...'
if timeout 5 bash -c '</dev/tcp/$SCW_TEM_IP/$SCW_TEM_PORT'; then
    echo '✅ IP $SCW_TEM_IP:$SCW_TEM_PORT reachable'
else
    echo '❌ IP $SCW_TEM_IP:$SCW_TEM_PORT not reachable'
    echo 'Trying alternative port 587...'
    timeout 5 bash -c '</dev/tcp/$SCW_TEM_IP/587' && echo '✅ IP $SCW_TEM_IP:587 reachable' || echo '❌ IP $SCW_TEM_IP:587 not reachable'
fi

echo ''
echo '2. Configuring Postfix for TEM relay...'
postconf -e 'smtp_address_preference = ipv4'
postconf -e 'inet_protocols = ipv4'
postconf -e 'relayhost = [$SCW_TEM_IP]:$SCW_TEM_PORT'
postconf -e 'smtp_sasl_auth_enable = yes'
postconf -e 'smtp_sasl_password_maps = lmdb:/etc/postfix/sasl/sasl_passwd'
postconf -e 'smtp_sasl_security_options = noanonymous'
postconf -e 'smtp_tls_security_level = encrypt'
postconf -e 'smtp_tls_note_starttls_offer = yes'

echo ''
echo '3. Creating SASL configuration...'
mkdir -p /etc/postfix/sasl/
echo '[$SCW_TEM_IP]:$SCW_TEM_PORT ${TEM_USER}:${API_KEY}' > /etc/postfix/sasl/sasl_passwd
postmap /etc/postfix/sasl/sasl_passwd
chmod 600 /etc/postfix/sasl/sasl_passwd /etc/postfix/sasl/sasl_passwd.lmdb

echo ''
echo '4. Reloading Postfix...'
postfix reload

echo ''
echo '5. Configuration complete!'
echo '=== Current Relay Settings ==='
postconf relayhost
postconf smtp_sasl_auth_enable
"

echo ""
echo "📧 Testing Outgoing Mail..."
kubectl -n $NAMESPACE exec -it $POD -- sh -c "
echo 'Subject: SCW Relay Test via IP
From: test@triggeriq.eu
To: your-email@gmail.com

Testing outgoing mail through Scaleway TEM using direct IP connection.' | sendmail -v your-email@gmail.com
"

echo ""
echo "🔍 Checking Mail Queue..."
sleep 3
kubectl -n $NAMESPACE exec -it $POD -- mailq

echo ""
echo "✅ Scaleway TEM Relay Configuration Complete using IP!"
echo ""
echo "📝 Note: Using direct IP $SCW_TEM_IP:$SCW_TEM_PORT to bypass DNS issues"