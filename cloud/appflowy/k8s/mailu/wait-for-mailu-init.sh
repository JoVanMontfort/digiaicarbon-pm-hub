#!/bin/bash

echo "🚀 Waiting for Mailu initialization..."

# Wait for Mailu admin pod to be ready
echo "⏳ Waiting for Mailu admin pod..."
kubectl wait --for=condition=ready pod -l app=mailu-admin -n mailcow --timeout=600s

echo "📊 Mailu admin is starting. Waiting for database initialization..."
sleep 30

# Check if tables are being created
echo "🔍 Checking database initialization progress..."
while true; do
    TABLE_COUNT=$(kubectl exec -it postgresql-0 -n mailcow -- psql -U mailcow -d mailcow -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null || echo "0")

    echo "📋 Current table count: $TABLE_COUNT"

    if [ "$TABLE_COUNT" -gt "10" ]; then
        echo "✅ Mailu database initialization completed with $TABLE_COUNT tables!"
        break
    fi

    echo "⏳ Waiting for more tables to be created..."
    sleep 10
done

echo "🎉 Mailu is fully initialized and ready!"