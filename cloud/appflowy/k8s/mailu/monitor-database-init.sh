#!/bin/bash

echo "🔍 Monitoring Mailu database initialization..."

while true; do
    clear
    echo "📊 Mailu Database Initialization Status"
    echo "========================================"

    # Check pod status
    echo ""
    echo "🏃 Pod Status:"
    kubectl get pods -n mailcow -l app=mailu- --no-headers | while read line; do
        POD=$(echo $line | awk '{print $1}')
        STATUS=$(echo $line | awk '{print $3}')
        READY=$(echo $line | awk '{print $2}')
        echo "  $POD: $STATUS ($READY)"
    done

    # Check database tables
    echo ""
    echo "🗃️ Database Tables:"
    TABLE_COUNT=$(kubectl exec -it postgresql-0 -n mailcow -- psql -U mailcow -d mailcow -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null || echo "0")
    echo "  Tables created: $TABLE_COUNT"

    # Check admin logs
    echo ""
    echo "📝 Admin Pod Logs (last 3 lines):"
    ADMIN_POD=$(kubectl get pods -n mailcow -l app=mailu-admin -o name 2>/dev/null | head -1)
    if [ ! -z "$ADMIN_POD" ]; then
        kubectl logs -n mailcow $ADMIN_POD --tail=3 2>/dev/null || echo "  Waiting for logs..."
    else
        echo "  Admin pod not ready yet..."
    fi

    # Exit condition
    if [ "$TABLE_COUNT" -gt "20" ]; then
        echo ""
        echo "🎉 Mailu initialization completed!"
        break
    fi

    echo ""
    echo "⏳ Refreshing in 5 seconds... (Press Ctrl+C to stop)"
    sleep 5
done