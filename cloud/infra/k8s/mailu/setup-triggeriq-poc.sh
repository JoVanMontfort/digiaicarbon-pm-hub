#!/bin/bash
NAMESPACE="mailcow"
POD="postfix-mail-7db6646f7f-vhsfm"

echo "🚀 Configuring with Correct TEM IP: 51.159.84.239"
echo "================================================"

kubectl -n $NAMESPACE exec -it $POD -- sh -c "
echo '1. Testing correct TEM IP connectivity...'
timeout 5 bash -c '</dev/tcp/51.159.84.239/2587' && echo '✅ IP 51.159.84.239:2587 reachable' || echo '❌ IP 51.159.84.239:2587 not reachable'

echo ''
echo '2. Configuring Postfix with correct IP...'
postconf -e 'smtp_address_preference = ipv4'
postconf -e 'inet_protocols = ipv4'
postconf -e 'relayhost = [51.159.84.239]:2587'

echo ''
echo '3. Creating SASL configuration...'
echo '[51.159.84.239]:2587 ${TEM_USER}:${API_SECRET}' > /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd
chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.lmdb

echo ''
echo '4. Reloading Postfix...'
postfix reload

echo ''
echo '5. Configuration complete with correct IP!'
postconf relayhost
"

#!/bin/bash
NAMESPACE="mailcow"
POD="postfix-mail-7db6646f7f-vhsfm"

echo "🚀 Setting Up triggeriq.eu Proof of Concept"
echo "=========================================="

kubectl -n $NAMESPACE exec -it $POD -- sh -c "
echo '1. Configuring Postfix for triggeriq.eu domain...'
postconf -e 'myhostname = mail.triggeriq.eu'
postconf -e 'mydomain = triggeriq.eu'
postconf -e 'myorigin = \$mydomain'
postconf -e 'mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain'
postconf -e 'mynetworks = 127.0.0.0/8, 100.64.0.0/10'
postconf -e 'inet_interfaces = all'

echo ''
echo '2. Setting up Scaleway Transactional Email relay...'
postconf -e 'relayhost = [smtp-relay.scaleway.com]:587'
postconf -e 'smtp_sasl_auth_enable = yes'
postconf -e 'smtp_sasl_password_maps = lmdb:/etc/postfix/sasl_passwd'
postconf -e 'smtp_sasl_security_options = noanonymous'
postconf -e 'smtp_tls_security_level = encrypt'

echo ''
echo '3. Creating SASL configuration...'
mkdir -p /etc/postfix/sasl/
echo '[smtp-relay.scaleway.com]:587 ${TEM_USER}:${API_SECRET}' > /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd
chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.lmdb

echo ''
echo '4. Reloading Postfix...'
postfix reload

echo ''
echo '5. Configuration complete for triggeriq.eu!'
postconf myhostname
postconf relayhost
"