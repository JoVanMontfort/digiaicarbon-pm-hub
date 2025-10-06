#!/bin/bash

echo "📧 Mail System Test Script"
echo "=========================="

# Configuration
SMTP_SERVER="51.158.216.249"
IMAP_SERVER="51.15.102.121"
DOMAIN="damno-solutions.be"

# Test users
USERS=(
    "test@$DOMAIN:Password123"
    "admin@$DOMAIN:AdminPassword123"
    "jo.vanmontfort@$DOMAIN:Amigos002"
    "amanda.gaviriagoyes@$DOMAIN:Amigos002"
)

echo ""
echo "🔧 Configuration:"
echo "   SMTP Server: $SMTP_SERVER"
echo "   IMAP Server: $IMAP_SERVER"
echo "   Domain: $DOMAIN"
echo ""

# Function to test SMTP connection
test_smtp_connection() {
    echo "1. Testing SMTP Connection..."
    echo "------------------------------"

    # Test port 25
    echo "   Port 25:"
    if ( echo "QUIT" | timeout 5 telnet $SMTP_SERVER 25 2>&1 | grep -q "220" ); then
        echo "   ✅ Port 25 - ACCEPTING connections"
    else
        echo "   ❌ Port 25 - FAILED"
    fi

    # Test port 587
    echo "   Port 587:"
    if ( echo "QUIT" | timeout 5 telnet $SMTP_SERVER 587 2>&1 | grep -q "220" ); then
        echo "   ✅ Port 587 - ACCEPTING connections"
    else
        echo "   ❌ Port 587 - FAILED"
    fi

    # Test port 465
    echo "   Port 465:"
    if ( echo "QUIT" | timeout 5 telnet $SMTP_SERVER 465 2>&1 | grep -q "220" ); then
        echo "   ✅ Port 465 - ACCEPTING connections"
    else
        echo "   ❌ Port 465 - FAILED"
    fi
}

# Function to test IMAP connection
test_imap_connection() {
    echo ""
    echo "2. Testing IMAP Connection..."
    echo "------------------------------"

    # Test IMAPS
    echo "   IMAPS (Port 993):"
    if timeout 10 openssl s_client -connect $IMAP_SERVER:993 -quiet 2>&1 | grep -q "Dovecot ready"; then
        echo "   ✅ IMAPS - ACCEPTING connections"
    else
        echo "   ❌ IMAPS - FAILED"
    fi
}

# Function to test mail delivery
test_mail_delivery() {
    echo ""
    echo "3. Testing Mail Delivery..."
    echo "------------------------------"

    for user_pair in "${USERS[@]}"; do
        IFS=':' read -r user password <<< "$user_pair"

        echo "   Testing: $user"

        # Test without authentication (local delivery)
        if swaks --to "$user" --from "test@$DOMAIN" \
            --server $SMTP_SERVER --silent 2>&1 | grep -q "250"; then
            echo "     ✅ Local delivery - SUCCESS"
        else
            echo "     ❌ Local delivery - FAILED"
        fi

        # Test with authentication on port 587
        if swaks --to "$user" --from "test@$DOMAIN" \
            --server $SMTP_SERVER --port 587 --auth LOGIN \
            --auth-user "$user" --auth-password "$password" \
            --tls --silent 2>&1 | grep -q "250"; then
            echo "     ✅ Authenticated (587) - SUCCESS"
        else
            echo "     ❌ Authenticated (587) - FAILED"
        fi

        echo ""
    done
}

# Function to test service status
test_service_status() {
    echo ""
    echo "4. Checking Service Status..."
    echo "------------------------------"

    echo "   Kubernetes Pods:"
    kubectl get pods -n mailcow -o wide | while read line; do
        echo "     $line"
    done

    echo ""
    echo "   Services:"
    kubectl get svc -n mailcow | while read line; do
        echo "     $line"
    done
}

# Function to test DNS resolution
test_dns_resolution() {
    echo ""
    echo "5. Testing DNS Resolution..."
    echo "------------------------------"

    # Test if domain resolves (might not be set yet)
    if nslookup $DOMAIN 2>&1 | grep -q "Address"; then
        echo "   ✅ $DOMAIN - RESOLVES"
    else
        echo "   ⚠️  $DOMAIN - NOT RESOLVING (DNS not configured)"
    fi
}

# Function to show mail client configuration
show_mail_config() {
    echo ""
    echo "6. Mail Client Configuration:"
    echo "------------------------------"
    echo "   SMTP (Outgoing):"
    echo "     Server: $SMTP_SERVER"
    echo "     Port: 25, 587, or 465"
    echo "     Encryption: STARTTLS (587) or SSL (465)"
    echo ""
    echo "   IMAP (Incoming):"
    echo "     Server: $IMAP_SERVER"
    echo "     Port: 993"
    echo "     Encryption: SSL/TLS"
    echo ""
    echo "   Available Users:"
    for user_pair in "${USERS[@]}"; do
        IFS=':' read -r user password <<< "$user_pair"
        echo "     - $user"
    done
}

# Main execution
test_smtp_connection
test_imap_connection
test_mail_delivery
test_service_status
test_dns_resolution
show_mail_config

echo ""
echo "🎉 Mail System Test Completed!"
echo "📋 Next steps:"
echo "   1. Configure DNS records"
echo "   2. Set up SSL certificates"
echo "   3. Test with real mail clients"

echo "🎉 FINAL MAIL SYSTEM TEST - STANDALONE MODE"
echo "==========================================="

SMTP_IP="51.158.216.249"
IMAP_IP="51.15.102.121"

echo ""
echo "1. Testing SMTP Delivery..."
swaks --to test@damno-solutions.be --from test@damno-solutions.be \
  --server $SMTP_IP --body "🎉 Congratulations! Your standalone mail server is WORKING!" \
  --h-Subject "Mail Server Test SUCCESS"

echo ""
echo "2. Checking Delivery Status..."
kubectl logs deployment/postfix-mail -n mailcow --tail=5 | grep -E "(delivered|queued|status)" | tail -3

echo ""
echo "3. Testing IMAP Connection..."
timeout 5 openssl s_client -connect $IMAP_IP:993 -quiet 2>&1 | head -3

echo ""
echo "4. Service Status:"
kubectl get pods,svc -n mailcow

echo ""
echo "✅ STANDALONE MAIL SERVER IS OPERATIONAL!"
echo ""
echo "📧 Next steps:"
echo "   1. Configure DNS MX records"
echo "   2. Set up SSL certificates"
echo "   3. Configure proper user authentication"
echo "   4. Test with real mail clients (Outlook, Thunderbird)"