#!/bin/bash

echo "🗃️ Setting up Mailu database..."

# Get secrets
DB_PASSWORD=$(kubectl get secret mailu-secrets -n mailcow -o jsonpath='{.data.db-password}' | base64 -d)
SECRET_KEY=$(kubectl get secret mailu-secrets -n mailcow -o jsonpath='{.data.secret-key}' | base64 -d)

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgresql -n mailcow --timeout=300s

echo "📊 Checking current database state..."
# Check if mailu database exists and has tables
TABLE_COUNT=$(kubectl exec -it postgresql-0 -n mailcow -- psql -U mailcow -d mailcow -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null || echo "0")

if [ "$TABLE_COUNT" -eq "0" ]; then
    echo "🔧 Database is empty. Mailu will initialize tables when admin pod starts."
else
    echo "✅ Database already has $TABLE_COUNT tables."
fi

echo "✅ Database setup completed."