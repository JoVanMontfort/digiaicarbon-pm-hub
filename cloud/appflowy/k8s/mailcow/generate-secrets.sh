#!/bin/bash

# Generate random passwords
POSTGRES_PASSWORD=$(openssl rand -base64 32)
ADMIN_PASSWORD=$(openssl rand -base64 16)

# Create secrets YAML
cat > mailcow-secrets.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: mailcow-secrets
  namespace: mailcow
type: Opaque
data:
  postgres-password: $(echo -n "$POSTGRES_PASSWORD" | base64 -w0)
  admin-password: $(echo -n "$ADMIN_PASSWORD" | base64 -w0)
  mysql-root-password: $(openssl rand -base64 32 | base64 -w0)
  rspamd-password: $(openssl rand -base64 16 | base64 -w0)
EOF

# Apply secrets
kubectl apply -f mailcow-secrets.yaml

# Save passwords to file (secure location)
cat > mailcow-passwords.txt << EOF
Mailcow Admin Password: $ADMIN_PASSWORD
PostgreSQL Password: $POSTGRES_PASSWORD
EOF

echo "🔐 Secrets generated and saved to mailcow-passwords.txt"
echo "⚠️  Store this file in a secure location!"