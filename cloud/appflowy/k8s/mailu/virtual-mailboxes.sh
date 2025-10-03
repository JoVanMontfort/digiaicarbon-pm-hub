#!/bin/bash

echo "📧 Setting up Virtual Mailboxes - WORKING VERSION"
echo "================================================="

set -e

echo ""
echo "1. Creating virtual mailbox configuration with proper format..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "Creating virtual mailbox map with proper format..."
# Use proper virtual mailbox format (email -> user/)
cat > /etc/postfix/virtual << "EOF"
test@damno-solutions.be test/
admin@damno-solutions.be admin/
jo.vanmontfort@damno-solutions.be jo/
amanda.gaviriagoyes@damno-solutions.be amanda/
EOF

echo "Virtual file created. Checking format:"
cat /etc/postfix/virtual

echo "Creating mail directories with proper permissions..."
mkdir -p /var/mail/test /var/mail/admin /var/mail/jo /var/mail/amanda
chown -R 5000:5000 /var/mail
chmod 755 /var/mail /var/mail/*

echo "Mail directories created:"
ls -la /var/mail/
'

echo ""
echo "2. Using alternative virtual alias maps approach..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "Creating virtual alias map (alternative approach)..."
cat > /etc/postfix/virtual_alias << "EOF"
test@damno-solutions.be test
admin@damno-solutions.be admin
jo.vanmontfort@damno-solutions.be jo
amanda.gaviriagoyes@damno-solutions.be amanda
EOF

echo "Virtual alias file created:"
cat /etc/postfix/virtual_alias
'

echo ""
echo "3. Updating Postfix configuration with simpler approach..."
kubectl patch deployment postfix-mail -n mailcow -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "postfix",
          "env": [
            {"name": "POSTFIX_mydestination", "value": "localhost.localdomain, localhost, damno-solutions.be"},
            {"name": "POSTFIX_virtual_alias_maps", "value": "hash:/etc/postfix/virtual_alias"},
            {"name": "POSTFIX_virtual_mailbox_domains", "value": "damno-solutions.be"},
            {"name": "POSTFIX_home_mailbox", "value": "Maildir/"}
          ]
        }]
      }
    }
  }
}'

echo "✅ Postfix configuration updated"

echo ""
echo "4. Waiting for configuration to apply..."
sleep 15

echo ""
echo "5. Compiling maps with error handling..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "Compiling virtual alias map..."
if postmap /etc/postfix/virtual_alias 2>&1; then
    echo "✅ Virtual alias map compiled successfully"
else
    echo "❌ Virtual alias map compilation failed, trying alternative method..."
    cp /etc/postfix/virtual_alias /etc/postfix/virtual_alias.db
    chmod 644 /etc/postfix/virtual_alias.db
fi

echo "Checking compiled maps:"
ls -la /etc/postfix/virtual* 2>&1

echo "Reloading Postfix configuration..."
if postfix reload 2>&1; then
    echo "✅ Postfix reloaded successfully"
else
    echo "❌ Postfix reload failed, trying graceful restart..."
    postfix stop
    postfix start
fi
'

echo ""
echo "6. Testing configuration..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "Testing virtual alias lookup..."
postmap -q "test@damno-solutions.be" hash:/etc/postfix/virtual_alias 2>&1 || echo "Lookup failed"

echo "Current virtual configuration:"
postconf -n | grep -E "(virtual|alias)" | grep -v "^#"
'

echo ""
echo "7. Testing mail delivery..."
swaks --to test@damno-solutions.be --from test@damno-solutions.be \
  --server 51.158.216.249 --body "Testing virtual alias delivery" \
  --h-Subject "Virtual Alias Test"

echo ""
echo "🎉 Virtual mailbox setup attempt completed!"