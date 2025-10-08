#!/bin/bash
echo "📬 Checking Delivered Mail"

echo "1. Checking mail content..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Latest mail files in test mailbox ==="
ls -lt /var/mail/test/new/ | head -5
echo "=== Reading latest email ==="
latest=$(ls -t /var/mail/test/new/ | head -1)
if [ -n "$latest" ]; then
    echo "File: $latest"
    cat "/var/mail/test/new/$latest"
else
    echo "No mail found"
fi
'

echo ""
echo "2. Testing from external source..."
echo "You can now test from an external email client:"
echo "SMTP Server: mail.triggeriq.eu"
echo "Ports: 25, 587, 465"
echo "Test email: test@triggeriq.eu"

echo ""
echo "3. Final configuration check..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Virtual configuration ==="
postconf virtual_mailbox_domains virtual_mailbox_maps virtual_transport
echo "=== Successful! Emails to @triggeriq.eu will be delivered to /var/mail/ ==="
'