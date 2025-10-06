#!/bin/bash

echo "🔧 Fixing Local Mail Delivery..."

echo "1. Updating Postfix for local delivery..."
kubectl patch deployment postfix-mail -n mailcow -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "postfix",
          "env": [
            {"name": "POSTFIX_mydestination", "value": "localhost.localdomain, localhost, damno-solutions.be, mail.damno-solutions.be"},
            {"name": "POSTFIX_local_recipient_maps", "value": ""},
            {"name": "POSTFIX_virtual_mailbox_domains", "value": "damno-solutions.be"},
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

echo "2. Creating virtual mailbox maps..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
cat > /etc/postfix/virtual_mailbox.pcre << EOF
/^test@damno-solutions\.be$/       test/
/^admin@damno-solutions\.be$/      admin/
/^jo\.vanmontfort@damno-solutions\.be$/ jo/
/^amanda\.gaviriagoyes@damno-solutions\.be$/ amanda/
EOF
'

echo "3. Restarting Postfix..."
kubectl rollout restart deployment/postfix-mail -n mailcow

echo "4. Waiting for restart..."
sleep 30

echo "✅ Local delivery configuration updated!"