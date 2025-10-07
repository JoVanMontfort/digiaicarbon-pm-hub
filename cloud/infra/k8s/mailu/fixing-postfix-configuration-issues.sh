#!/bin/bash

echo "🔧 Fixing Postfix Configuration Issues..."

echo "1. Creating virtual_mailbox.pcre file..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
mkdir -p /etc/postfix
cat > /etc/postfix/virtual_mailbox.pcre << EOF
/^test@triggeriq\.eu$/       test/
/^admin@triggeriq\.eu$/      admin/
/^info@triggeriq\.eu$/       info/
/^support@triggeriq\.eu$/    support/
EOF
postmap /etc/postfix/virtual_mailbox.pcre
'

echo "2. Fixing Postfix configuration to avoid domain conflict..."
kubectl patch deployment postfix-mail -n mailcow -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "postfix",
          "env": [
            {"name": "POSTFIX_mydestination", "value": "localhost.localdomain, localhost, mail.triggeriq.eu"},
            {"name": "POSTFIX_myhostname", "value": "mail.triggeriq.eu"},
            {"name": "POSTFIX_local_recipient_maps", "value": ""},
            {"name": "POSTFIX_virtual_mailbox_domains", "value": "triggeriq.eu"},
            {"name": "POSTFIX_virtual_mailbox_base", "value": "/var/mail"},
            {"name": "POSTFIX_virtual_mailbox_maps", "value": "pcre:/etc/postfix/virtual_mailbox.pcre"},
            {"name": "POSTFIX_virtual_uid_maps", "value": "static:5000"},
            {"name": "POSTFIX_virtual_gid_maps", "value": "static:5000"}
          ]
        }]
      }
    }
  }
}'

echo "3. Restarting Postfix..."
kubectl rollout restart deployment/postfix-mail -n mailcow

echo "4. Waiting for restart..."
sleep 30

echo "5. Verifying configuration..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Checking files ==="
ls -la /etc/postfix/virtual_mailbox.pcre
echo "=== Checking Postfix config ==="
postconf mydestination
postconf virtual_mailbox_domains
postconf myhostname
'

echo "✅ Fixes applied! Testing..."