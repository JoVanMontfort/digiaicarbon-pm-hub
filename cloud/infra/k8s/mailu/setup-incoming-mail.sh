#!/bin/bash
NAMESPACE="mailcow"
POD="postfix-mail-7db6646f7f-vhsfm"

echo "🔧 Configuring Postfix for Incoming Mail"
echo "======================================"

kubectl -n $NAMESPACE exec -it $POD -- sh -c "
echo '1. Current incoming mail configuration:'
postconf -n | grep -E '(mydestination|virtual_mailbox_domains|virtual_alias_maps)'

echo ''
echo '2. Configuring domains to accept mail for...'
postconf -e 'mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain, triggeriq.eu, damno-solutions.be'
postconf -e 'virtual_mailbox_domains = triggeriq.eu, damno-solutions.be'
postconf -e 'virtual_mailbox_base = /var/mail'
postconf -e 'virtual_mailbox_maps = hash:/etc/postfix/virtual_mailbox'
postconf -e 'virtual_uid_maps = static:5000'
postconf -e 'virtual_gid_maps = static:5000'

echo ''
echo '3. Creating virtual mailbox maps...'
echo 'test@triggeriq.eu   triggeriq.eu/test/' > /etc/postfix/virtual_mailbox
postmap /etc/postfix/virtual_mailbox

echo ''
echo '4. Creating alias maps...'
echo 'test@triggeriq.eu    test' > /etc/postfix/virtual
postmap /etc/postfix/virtual
postconf -e 'virtual_alias_maps = hash:/etc/postfix/virtual'

echo ''
echo '5. Setting up mail directory structure...'
mkdir -p /var/mail/triggeriq.eu/test
chown -R 5000:5000 /var/mail

echo ''
echo '6. Reloading Postfix...'
postfix reload

echo ''
echo '7. Incoming mail configuration complete!'
postconf mydestination
postconf virtual_mailbox_domains
"