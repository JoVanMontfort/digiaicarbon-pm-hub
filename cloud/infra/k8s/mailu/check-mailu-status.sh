#!/bin/bash

echo "📊 Mailu Status Check"

echo ""
echo "🔍 Pods:"
kubectl get pods -n mailcow -l app=mailu-

echo ""
echo "🌐 Services:"
kubectl get svc -n mailcow -l app=mailu-

echo ""
echo "📝 Logs (last 5 lines each):"
for pod in $(kubectl get pods -n mailcow -l app=mailu- -o name); do
  echo ""
  echo "📄 $pod:"
  kubectl logs -n mailcow $pod --tail=5
done

echo ""
echo "🔄 Database connection:"
kubectl exec -it postgresql-0 -n mailcow -- psql -U mailcow -d mailcow -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';"