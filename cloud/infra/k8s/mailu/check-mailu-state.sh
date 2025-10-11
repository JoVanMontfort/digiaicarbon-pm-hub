#!/bin/bash

echo "🔍 Investigating Mailu Setup"
echo "==========================="

NAMESPACE="mailcow"  # This is actually Mailu!

echo "🚫 Port-forwarding disabled - no browser available in SCW Kapsule"
echo "================================================================"

# Kill any existing port-forward processes
pkill -f "kubectl port-forward.*mailu-admin" 2>/dev/null && echo "✅ Stopped existing port-forward" || echo "ℹ️ No port-forward running"

echo ""
echo "1. Checking Mailu Admin Interface..."
echo "-----------------------------------"
kubectl get svc -n $NAMESPACE mailu-admin -o wide

echo ""
echo "2. Accessing Mailu Admin..."
echo "--------------------------"
# Mailu admin is ClusterIP, so we need to port-forward
echo "To access Mailu admin, run:"
echo "kubectl port-forward -n $NAMESPACE svc/mailu-admin 8080:80"
echo "Then open: http://localhost:8080"

echo ""
echo "3. Checking Mailu Configuration..."
echo "---------------------------------"
kubectl get configmap mailu-config -n $NAMESPACE -o yaml

echo ""
echo "4. Checking Mailu Database Status..."
echo "-----------------------------------"
# Mailu might not have initialized the database yet
kubectl exec -n $NAMESPACE postgresql-0 -- psql -U mailu -d mailu -c "\dt" 2>/dev/null || echo "Trying with mailu user..."

echo ""
echo "5. Current Mail Storage..."
echo "-------------------------"
kubectl exec -n $NAMESPACE dovecot-mail-79b96d4cf4-4km2x -- find /var/vmail -type d 2>/dev/null | head -10

echo "🚀 Accessing Mailu Admin Interface"
echo "================================="

echo ""
echo "1. Start port-forwarding:"
echo "kubectl port-forward -n mailcow svc/mailu-admin 8080:80 &"

echo ""
echo "2. Open your browser to:"
echo "http://localhost:8080"

echo ""
echo "3. Default Mailu credentials:"
echo "   Username: admin"
echo "   Password: [check Mailu setup or config]"

echo ""
echo "4. In Mailu admin, you can:"
echo "   - Add domain: triggeriq.eu"
echo "   - Create users: test@triggeriq.eu, admin@triggeriq.eu, etc."
echo "   - Manage email accounts"

echo "📊 Mailu Component Status"
echo "========================"

echo ""
echo "✅ Running:"
echo "   - Postfix (with your virtual mailboxes)"
echo "   - Dovecot (IMAP server)"
echo "   - PostgreSQL (empty database)"
echo "   - Mailu Admin (management interface)"

echo ""
echo "❌ Missing:"
echo "   - Mailu database initialization"
echo "   - Domain configuration"
echo "   - User accounts"

echo "🚫 Port-forwarding disabled - no browser available in SCW Kapsule"
echo "================================================================"

# Kill any existing port-forward processes
pkill -f "kubectl port-forward.*mailu-admin" 2>/dev/null && echo "✅ Stopped existing port-forward" || echo "ℹ️ No port-forward running"