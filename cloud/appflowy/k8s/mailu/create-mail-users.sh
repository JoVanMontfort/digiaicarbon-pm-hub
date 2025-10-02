#!/bin/bash

echo "📧 Creating mail users..."

# Exec into Dovecot container om users toe te voegen
kubectl exec -it deployment/dovecot-mail -n mailcow -- sh -c '
# Voorbeeld: user aanmaken (moet worden aangepast voor jouw setup)
echo "test@damno-solutions.be:$(openssl passwd -5 Password123)" >> /etc/dovecot/users
echo "admin@damno-solutions.be:$(openssl passwd -5 AdminPassword123)" >> /etc/dovecot/users

# Restart Dovecot om changes te laden
pkill -HUP dovecot
'

echo "✅ Sample users created. Update passwords for production!"