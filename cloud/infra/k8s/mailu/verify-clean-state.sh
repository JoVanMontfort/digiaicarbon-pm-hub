#!/bin/bash
NAMESPACE="mailcow"
POD=$(kubectl get pods -n mailcow -l app=postfix-mail -o jsonpath='{.items[0].metadata.name}')

echo "✅ Verifying Clean Postfix State"
echo "==============================="

kubectl -n $NAMESPACE exec -it $POD -- sh -c "
echo '1. Current Postfix configuration:'
postconf -n | grep -E '(myhostname|mydomain|relayhost|sasl|mynetworks)'

echo ''
echo '2. Mail queue status:'
postqueue -p

echo ''
echo '3. Network configuration:'
postconf inet_interfaces
postconf mynetworks

echo ''
echo '4. Files in /etc/postfix:'
ls -la /etc/postfix/ | grep -E '(sasl|passwd)' || echo 'No SASL/password files - perfect!'

echo ''
echo '5. Postfix process status:'
poststatus
"