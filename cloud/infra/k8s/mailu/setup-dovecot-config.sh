#!/bin/bash

echo "📧 Configuring Existing Dovecot for Virtual Mailboxes"
echo "===================================================="

NAMESPACE="mailcow"
DOVECOT_POD="dovecot-mail-79b96d4cf4-4km2x"

echo ""
echo "1. Checking Current Dovecot Configuration..."
echo "-------------------------------------------"

kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "=== Current config files ==="
ls -la /etc/dovecot/conf.d/ | head -10

echo ""
echo "=== Checking auth config ==="
grep -r "mail_location" /etc/dovecot/conf.d/ 2>/dev/null | head -5
'

echo ""
echo "2. Testing Current IMAP Access..."
echo "-------------------------------"

DOVECOT_IP="51.15.102.121"

echo "🌐 Dovecot Service IP: $DOVECOT_IP"
echo ""
echo "📧 Current Thunderbird Configuration:"
echo "   Server: $DOVECOT_IP"
echo "   Port: 143 (IMAP) or 993 (IMAPS)"
echo "   Username: [need to check mailcow users]"
echo "   Password: [mailcow password]"

echo ""
echo "3. Checking Mailcow User Setup..."
echo "-------------------------------"

# Check if mailcow has user database
kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "=== Checking for user databases ==="
find /etc/dovecot/ -name "*.conf" -exec grep -l "passwd\\|sql\\|ldap" {} \; 2>/dev/null

echo ""
echo "=== Checking mail directories ==="
ls -la /var/mail/ 2>/dev/null || echo "/var/mail/ not found"
'

echo ""
echo "4. Testing IMAP Login (if users exist)..."
echo "---------------------------------------"

# Test if we can connect to IMAP
echo "🔌 Testing IMAP connection..."
telnet $DOVECOT_IP 143 <<EOF
QUIT
EOF

if [ $? -eq 0 ]; then
    echo "✅ IMAP connection successful"
else
    echo "❌ IMAP connection failed"
fi

echo "🔍 Investigating Mailcow User Setup"
echo "=================================="

# Check for mailcow's user management
kubectl get pods -n mailcow | grep -E "(admin|webmail|roundcube|php)"

# Check for database
kubectl get pods -n mailcow | grep -E "(mysql|mariadb|postgres)"

echo ""
echo "📋 Mailcow Components Found:"
kubectl get pods -n mailcow --no-headers | awk "{print \$1}" | while read pod; do
    echo " - $pod"
done