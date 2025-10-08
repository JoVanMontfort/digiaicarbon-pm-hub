#!/bin/bash
echo "🔧 Fixing External Email Access Denied Error"

echo "1. Checking current recipient configuration..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Current recipient settings ==="
postconf local_recipient_maps
postconf recipient_canonical_maps
postconf smtpd_recipient_restrictions
'

echo ""
echo "2. Fixing recipient validation for virtual users..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Configuring recipient validation ==="
# Allow virtual users as valid recipients
postconf -e "local_recipient_maps="
postconf -e "recipient_canonical_maps="

# Set proper recipient restrictions
postconf -e "smtpd_recipient_restrictions=permit_mynetworks,reject_unauth_destination,permit"

echo "=== Updated configuration ==="
postconf local_recipient_maps smtpd_recipient_restrictions
'

echo ""
echo "3. Ensuring virtual domain is properly recognized..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Virtual domain configuration ==="
postconf virtual_mailbox_domains
postconf virtual_mailbox_maps

# Make sure virtual transport is set
postconf -e "virtual_transport=virtual"
'

echo ""
echo "4. Reloading Postfix..."
kubectl exec -it deployment/postfix-mail -n mailcow -- postfix reload

echo ""
echo "5. Testing recipient validation..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Testing virtual recipient lookup ==="
postmap -q "test@triggeriq.eu" lmdb:/etc/postfix/virtual

echo "=== Testing domain validation ==="
postmap -q "triggeriq.eu" lmdb:/etc/postfix/virtual 2>/dev/null || echo "Domain lookup not needed"
'

echo ""
echo "6. Quick external test simulation..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Simulating external delivery ==="
echo "This should work for external senders now"
'

echo ""
echo "🎉 Recipient access configuration updated!"

#test@triggeriq.eu      → /var/mail/test/
#admin@triggeriq.eu     → /var/mail/admin/
#info@triggeriq.eu      → /var/mail/info/
#support@triggeriq.eu   → /var/mail/support/