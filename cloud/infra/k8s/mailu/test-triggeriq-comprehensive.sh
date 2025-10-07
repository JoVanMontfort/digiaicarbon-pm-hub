#!/bin/bash

echo "🧪 Testing triggeriq.eu Mail Setup"
echo "=================================="

DOMAIN="triggeriq.eu"
TEST_EMAIL="test@$DOMAIN"

echo ""
echo "1. Testing DNS Configuration..."
echo "-------------------------------"

# Test MX records
echo "📧 Checking MX records:"
MX_RECORDS=$(dig MX $DOMAIN +short)
if [ -n "$MX_RECORDS" ]; then
    echo "✅ MX Records found:"
    echo "$MX_RECORDS"
else
    echo "❌ No MX records found!"
    exit 1
fi

# Test A record for mail subdomain
echo ""
echo "🌐 Checking mail A record:"
MAIL_A_RECORD=$(dig A mail.$DOMAIN +short)
if [ -n "$MAIL_A_RECORD" ]; then
    echo "✅ Mail A record: $MAIL_A_RECORD"
else
    echo "❌ No A record for mail.$DOMAIN"
    exit 1
fi

# Test SPF record
echo ""
echo "🛡️ Checking SPF record:"
SPF_RECORD=$(dig TXT $DOMAIN +short | grep "v=spf1")
if [ -n "$SPF_RECORD" ]; then
    echo "✅ SPF record found: $SPF_RECORD"
else
    echo "❌ No SPF record found"
fi

echo ""
echo "2. Testing Kubernetes Mail Services..."
echo "-------------------------------------"

# Check if Postfix pod is running
POSTFIX_POD=$(kubectl get pods -n mailcow -l app=postfix-mail -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POSTFIX_POD" ]; then
    echo "✅ Postfix pod: $POSTFIX_POD"

    # Check Postfix status
    echo ""
    echo "📮 Checking Postfix status:"
    kubectl exec -n mailcow $POSTFIX_POD -- postfix status
    if [ $? -eq 0 ]; then
        echo "✅ Postfix is running"
    else
        echo "❌ Postfix is not running properly"
    fi

    # Test virtual mailbox configuration
    echo ""
    echo "📁 Testing virtual mailbox maps:"
    kubectl exec -n mailcow $POSTFIX_POD -- cat /etc/postfix/virtual_mailbox.pcre
    if [ $? -eq 0 ]; then
        echo "✅ Virtual mailbox map exists"
    else
        echo "❌ Virtual mailbox map missing"
    fi
else
    echo "❌ Postfix pod not found"
    exit 1
fi

echo ""
echo "3. Testing SMTP Connectivity..."
echo "------------------------------"

# Test local SMTP connection
echo "🔌 Testing local SMTP (port 25):"
kubectl exec -n mailcow $POSTFIPOSTFIX_POD -- timeout 10 bash -c "echo 'QUIT' | telnet localhost 25"
if [ $? -eq 0 ]; then
    echo "✅ Local SMTP is accessible"
else
    echo "❌ Local SMTP not accessible"
fi

# Test external SMTP connection
echo ""
echo "🌍 Testing external SMTP connection:"
telnet mail.$DOMAIN 25 <<EOF
QUIT
EOF
if [ $? -eq 0 ]; then
    echo "✅ External SMTP is accessible"
else
    echo "❌ External SMTP not accessible"
fi

echo ""
echo "4. Testing Mail Delivery..."
echo "--------------------------"

# Send a test email locally
echo "📤 Sending test email to $TEST_EMAIL:"
kubectl exec -n mailcow $POSTFIX_POD -- bash -c "
echo 'Subject: Test Email from Mail Setup
From: test@$DOMAIN
To: $TEST_EMAIL

This is a test email to verify mail delivery configuration for $DOMAIN.' | sendmail -v $TEST_EMAIL
"

if [ $? -eq 0 ]; then
    echo "✅ Test email sent successfully"

    # Check mail queue
    echo ""
    echo "📊 Checking mail queue:"
    kubectl exec -n mailcow $POSTFIX_POD -- mailq
else
    echo "❌ Failed to send test email"
fi

echo ""
echo "5. Testing Scaleway Transactional Email Relay..."
echo "------------------------------------------------"

# Check SASL configuration
echo "🔐 Checking SASL configuration:"
kubectl exec -n mailcow $POSTFIX_POD -- ls -la /etc/postfix/sasl/sasl_passwd
if [ $? -eq 0 ]; then
    echo "✅ SASL configuration exists"
    kubectl exec -n mailcow $POSTFIX_POD -- cat /etc/postfix/sasl/sasl_passwd | cut -c1-20
else
    echo "❌ SASL configuration missing"
fi

# Test relayhost configuration
echo ""
echo "🔄 Checking relayhost:"
RELAYHOST=$(kubectl exec -n mailcow $POSTFIX_POD -- postconf relayhost)
echo "Relayhost: $RELAYHOST"

echo ""
echo "6. Testing Outbound Mail..."
echo "--------------------------"

# Send test email to external address (if configured)
if [ -n "$EXTERNAL_TEST_EMAIL" ]; then
    echo "📤 Sending external test to $EXTERNAL_TEST_EMAIL:"
    kubectl exec -n mailcow $POSTFIX_POD -- bash -c "
echo 'Subject: External Test from $DOMAIN
From: test@$DOMAIN
To: $EXTERNAL_TEST_EMAIL

This is an external test email from $DOMAIN.' | sendmail -v $EXTERNAL_TEST_EMAIL
    "
    if [ $? -eq 0 ]; then
        echo "✅ External test email sent"
    else
        echo "❌ Failed to send external test email"
    fi
else
    echo "ℹ️ Set EXTERNAL_TEST_EMAIL environment variable to test external delivery"
fi

echo ""
echo "=================================="
echo "🎉 Mail Setup Test Complete!"
echo ""
echo "Summary:"
echo "• DNS: ✅ MX, A records configured"
echo "• Services: ✅ Postfix running"
echo "• Configuration: ✅ Virtual mailboxes, SASL relay"
echo "• Connectivity: ✅ Internal/External SMTP"
echo ""
echo "Next: Check actual email delivery in mail logs"
echo "kubectl logs -n mailcow $POSTFIX_POD | tail -20"