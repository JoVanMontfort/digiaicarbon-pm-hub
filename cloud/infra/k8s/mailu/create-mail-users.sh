#!/bin/bash

echo "📧 Creating mail users in Dovecot..."

# Exec into Dovecot container to add users
kubectl exec -it deployment/dovecot-mail -n mailcow -- sh -c '
echo "🔐 Creating user passwords..."

# Create users with encrypted passwords
echo "test@damno-solutions.be:$(openssl passwd -5 "Password123")" >> /etc/dovecot/users
echo "admin@damno-solutions.be:$(openssl passwd -5 "AdminPassword123")" >> /etc/dovecot/users
echo "jo.vanmontfort@damno-solutions.be:$(openssl passwd -5 "Amigos002002")" >> /etc/dovecot/users
echo "amanda.gaviriagoyes@damno-solutions.be:$(openssl passwd -5 "Amigos002002")" >> /etc/dovecot/users

echo "✅ Users added to /etc/dovecot/users"

# Restart Dovecot to load changes
echo "🔄 Restarting Dovecot..."
pkill -HUP dovecot

echo "✅ Dovecot reloaded with new users"
'

echo ""
echo "🎉 Mail users created successfully!"
echo ""
echo "📋 Created users:"
echo "   - test@damno-solutions.be"
echo "   - admin@damno-solutions.be"
echo "   - jo.vanmontfort@damno-solutions.be"
echo "   - amanda.gaviriagoyes@damno-solutions.be"
echo ""
echo "⚠️  Important:"
echo "   - Update passwords for production use"
echo "   - Consider using a database for user management"
echo "   - The '&' character was removed from passwords for safety"