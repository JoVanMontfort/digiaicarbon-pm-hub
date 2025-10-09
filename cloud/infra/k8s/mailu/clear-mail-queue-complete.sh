#!/bin/bash
NAMESPACE="mailcow"
POD=$(kubectl get pods -n mailcow -l app=postfix-mail -o jsonpath='{.items[0].metadata.name}')

echo "🧹 COMPLETELY Clearing Mail Queue"
echo "================================"

kubectl -n $NAMESPACE exec -it $POD -- sh -c "
echo '1. Current queue count before cleanup:'
QUEUE_COUNT=\$(postqueue -p | grep -c '^[A-F0-9]')
echo \"   Found: \$QUEUE_COUNT emails in queue\"

echo ''
echo '2. Removing ALL queued emails...'
postsuper -d ALL

echo ''
echo '3. Verify queue is empty:'
EMPTY_COUNT=\$(postqueue -p | grep -c '^[A-F0-9]')
echo \"   Queue count after cleanup: \$EMPTY_COUNT\"

if [ \"\$EMPTY_COUNT\" -eq \"0\" ]; then
    echo '   ✅ Queue is now empty!'
else
    echo '   ⚠️  Queue still has emails - trying alternative method...'
    postqueue -p | grep '^[A-F0-9]' | awk '{print \$1}' | postsuper -d -
    echo '   Final queue count:'
    postqueue -p | grep -c '^[A-F0-9]'
fi

echo ''
echo '4. Check Postfix status:'
postqueue -p

echo ''
echo '5. Recent log entries:'
tail -5 /var/log/mail.log
"