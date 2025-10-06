#!/bin/bash
NAMESPACE="mailcow"
POD="postfix-mail-7db6646f7f-vhsfm"

echo "🔄 COMPLETE Postfix Reset"
echo "========================"

kubectl -n $NAMESPACE exec -it $POD -- sh -c "
echo '1. Stopping Postfix...'
postfix stop

echo ''
echo '2. Removing ALL configuration changes...'
# Remove all custom configs and return to defaults
postconf -X relayhost
postconf -X smtp_sasl_auth_enable
postconf -X smtp_sasl_password_maps
postconf -X smtp_sasl_security_options
postconf -X smtp_tls_security_level
postconf -X smtp_address_preference
postconf -X smtp_bind_address
postconf -X inet_protocols
postconf -X smtp_sasl_mechanism_filter

echo ''
echo '3. Removing SASL configuration...'
rm -rf /etc/postfix/sasl/
rm -f /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db /etc/postfix/sasl_passwd.lmdb

echo ''
echo '4. Clearing mail queue...'
postsuper -d ALL

echo ''
echo '5. Reset to basic configuration...'
postconf -e 'myhostname = mail.damno-solutions.be'
postconf -e 'mydomain = damno-solutions.be'
postconf -e 'myorigin = \$mydomain'
postconf -e 'mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain'
postconf -e 'mynetworks = 127.0.0.0/8, 100.64.0.0/10'
postconf -e 'inet_interfaces = all'
postconf -e 'home_mailbox = Maildir/'

echo ''
echo '6. Starting Postfix with clean config...'
postfix start

echo ''
echo '7. Verifying clean state...'
postconf -n | grep -E '(myhostname|mydomain|relayhost|sasl)'
echo ''
echo 'Queue status:'
postqueue -p
echo ''
echo 'SASL files (should be none):'
ls -la /etc/postfix/sasl* 2>/dev/null || echo 'No SASL files - good!'
"