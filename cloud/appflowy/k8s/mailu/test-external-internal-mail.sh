#!/bin/bash

echo "📧 Testing External & Internal Mail Delivery"
echo "============================================"

SMTP_SERVER="51.158.216.249"
EXTERNAL_EMAIL="jovm007me@gmail.com"
INTERNAL_EMAIL="jo.vanmontfort@damno-solutions.be"
TEST_FROM="test@damno-solutions.be"

echo ""
echo "🔧 Configuration:"
echo "   SMTP Server: $SMTP_SERVER"
echo "   External To: $EXTERNAL_EMAIL"
echo "   Internal To: $INTERNAL_EMAIL"
echo "   From: $TEST_FROM"

echo ""
echo "1. Testing INTERNAL Mail Delivery..."
echo "------------------------------------"
swaks --to "$INTERNAL_EMAIL" --from "$TEST_FROM" \
  --server $SMTP_SERVER \
  --body "This is a test INTERNAL email from your mail server.

Server: $SMTP_SERVER
Time: $(date)
Test: Internal delivery to @damno-solutions.be

If you receive this, internal mail delivery is WORKING! 🎉" \
  --h-Subject "✅ INTERNAL Mail Test - $(date +"%H:%M:%S")"

echo ""
echo "2. Testing EXTERNAL Mail Delivery..."
echo "------------------------------------"
swaks --to "$EXTERNAL_EMAIL" --from "$TEST_FROM" \
  --server $SMTP_SERVER \
  --body "This is a test EXTERNAL email from your mail server.

Server: $SMTP_SERVER
Domain: damno-solutions.be
Time: $(date)
Test: External delivery to Gmail

If you receive this, your mail server can send to external domains! 🚀" \
  --h-Subject "🌍 EXTERNAL Mail Test - $(date +"%H:%M:%S")"

echo ""
echo "3. Checking Delivery Status in Logs..."
echo "--------------------------------------"
echo "Waiting 10 seconds for mail processing..."
sleep 10

kubectl logs deployment/postfix-mail -n mailcow --tail=20 | grep -E "(from=<$TEST_FROM|to=<($INTERNAL_EMAIL|$EXTERNAL_EMAIL)|status=)" | tail -10

echo ""
echo "4. Checking Mail Queue..."
echo "-------------------------"
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "Active queue:"
postqueue -p 2>/dev/null | head -5 || echo "Queue empty or command not available"

echo "Recent log entries:"
tail -10 /var/log/mail.log 2>/dev/null | grep -E "(smtp|local)" || echo "No recent log entries"
'

echo ""
echo "5. Testing Local Mail Files..."
echo "------------------------------"
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "Checking for local mail files:"
find /var/mail/ -type f -name "*" 2>/dev/null

for user_dir in /var/mail/*/; do
    if [ -d "$user_dir" ]; then
        user=$(basename "$user_dir")
        echo "--- $user ---"
        find "$user_dir" -type f -exec ls -la {} \; 2>/dev/null
    fi
done
'

echo ""
echo "🎉 Test Completed!"
echo ""
echo "📋 Expected Results:"
echo "   ✅ INTERNAL: Should be delivered to /var/mail/jo/"
echo "   ⚠️  EXTERNAL: May be queued or fail (depends on DNS/MX config)"
echo ""
echo "🔍 Next: Check Gmail inbox for external test and logs for internal delivery"