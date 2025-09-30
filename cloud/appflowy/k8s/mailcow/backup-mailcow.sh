#!/bin/bash

# Backup script for Mailcow on Kubernetes
BACKUP_DIR="/backup/mailcow-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR

echo "💾 Starting Mailcow backup..."

# Backup PostgreSQL
kubectl exec -n mailcow deployment/postgresql -- pg_dump -U mailcow mailcow > $BACKUP_DIR/postgresql.sql

# Backup configuration
kubectl get configmap mailcow-config -n mailcow -o yaml > $BACKUP_DIR/configmap.yaml
kubectl get secret mailcow-secrets -n mailcow -o yaml > $BACKUP_DIR/secrets.yaml

# Backup PVC data (if you have direct access)
# tar -czf $BACKUP_DIR/mail-data.tar.gz /path/to/mailcow-data/

echo "✅ Backup completed: $BACKUP_DIR"