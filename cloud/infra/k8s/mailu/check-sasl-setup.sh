#!/bin/bash
NAMESPACE="mailcow"
POD="postfix-mail-7db6646f7f-vhsfm"

echo "🔍 Checking SASL Setup"
echo "====================="

kubectl -n $NAMESPACE exec -it $POD -- sh -c "
echo '1. Current sasl_passwd file:'
ls -la /etc/postfix/sasl_passwd*
if [ -f /etc/postfix/sasl_passwd ]; then
    echo 'Content:'
    cat /etc/postfix/sasl_passwd
    echo ''
    echo 'Testing lookup:'
    postmap -q '[smtp.gmail.com]:587' lmdb:/etc/postfix/sasl_passwd
else
    echo '❌ No sasl_passwd file found!'
fi

echo ''
echo '2. Current relay configuration:'
postconf relayhost
postconf smtp_sasl_auth_enable
postconf smtp_sasl_password_maps

echo ''
echo '3. Available SASL mechanisms:'
postconf smtp_sasl_mechanism_filter

echo ''
echo '4. Check if emails are trying to authenticate:'
tail -15 /var/log/mail.log | grep -i 'sasl\|auth'
"