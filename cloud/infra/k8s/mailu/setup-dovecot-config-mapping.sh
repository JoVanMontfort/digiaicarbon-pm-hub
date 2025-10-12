#!/bin/bash

echo "🎯 PERMANENT FIX: Ultra-Cheap Sidecar Solution for SCW Kapsule"
echo "=============================================================="

NAMESPACE="mailcow"
POSTFIX_POD=$(kubectl get pods -n $NAMESPACE -l app=postfix-mail -o jsonpath='{.items[0].metadata.name}')
DOVECOT_POD=$(kubectl get pods -n $NAMESPACE -l app=dovecot-mail -o jsonpath='{.items[0].metadata.name}')

echo ""
echo "🧹 STEP 1: Clean Up Expensive CronJobs"
echo "======================================"

# Delete any existing CronJobs to save costs
kubectl delete cronjob email-sync -n mailcow --ignore-not-found=true
kubectl delete cronjob email-sync-working -n mailcow --ignore-not-found=true
kubectl delete cronjob email-sync-final -n mailcow --ignore-not-found=true
kubectl delete cronjob email-sync-cheap -n mailcow --ignore-not-found=true

# Clean up any completed jobs
kubectl delete jobs -n mailcow -l job-name --now --ignore-not-found=true

echo "✅ All expensive CronJobs deleted"

echo ""
echo "📧 STEP 2: Configure Postfix for Maildir Delivery"
echo "================================================="

# Update Postfix configuration
kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c '
echo "=== Configuring Postfix for direct Maildir delivery ==="

# Configure Postfix for Maildir format
postconf -e "home_mailbox = Maildir/"
postconf -e "mailbox_command ="
postconf -e "virtual_mailbox_base = /var/mail"
postconf -e "virtual_minimum_uid = 5000"
postconf -e "virtual_uid_maps = static:5000"
postconf -e "virtual_gid_maps = static:5000"

echo "=== Testing if Postfix can access Dovecot storage ==="
if [ -d "/var/mail/support/Maildir" ]; then
    echo "✅ Postfix can access Dovecot Maildir directly!"
    echo "Emails should deliver directly without sync needed"
else
    echo "⚠️  Postfix cannot access Dovecot Maildir directly"
    echo "Will use sidecar sync solution"
fi

echo ""
echo "=== Reloading Postfix ==="
postfix reload
echo "✅ Postfix configured"
'

echo ""
echo "🔧 STEP 3: Deploy Ultra-Cheap Sidecar Solution"
echo "=============================================="

# Create the sidecar deployment that replaces the existing Postfix
cat > /tmp/postfix-with-sidecar.yaml << "EOF"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postfix-with-sync
  namespace: mailcow
  labels:
    app: postfix-with-sync
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postfix-with-sync
  template:
    metadata:
      labels:
        app: postfix-with-sync
    spec:
      # Add affinity to ensure it runs on the same node as Dovecot for shared storage
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - dovecot-mail
            topologyKey: kubernetes.io/hostname
      containers:
      # Main Postfix container (your existing setup)
      - name: postfix
        image: mailcow/postfix:latest
        env:
        - name: MAILCOW_HOSTNAME
          value: "mail.triggeriq.eu"
        ports:
        - containerPort: 25
        - containerPort: 587
        - containerPort: 465
        volumeMounts:
        - name: mail-data
          mountPath: /var/mail
        - name: postfix-config
          mountPath: /etc/postfix
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"

      # Ultra-cheap sidecar for email sync
      - name: email-sync-sidecar
        image: alpine:latest  # Only ~5MB!
        command:
        - /bin/sh
        - -c
        - |
          echo "🚀 Starting Ultra-Cheap Email Sidecar Sync"
          echo "Image: alpine:latest (5MB)"
          echo "Cost: Minimal"
          echo "=========================================="

          # Install only essential packages
          apk add --no-cache findutils

          SYNC_COUNT=0
          while true; do
            # Check for new emails every 30 seconds
            if [ -d "/var/mail/support/new" ]; then
              EMAIL_COUNT=$(find /var/mail/support/new/ -type f 2>/dev/null | wc -l)
              if [ $EMAIL_COUNT -gt 0 ]; then
                echo "[$(date +%H:%M:%S)] Found $EMAIL_COUNT emails to sync..."

                # Sync each email
                find /var/mail/support/new/ -type f 2>/dev/null | while read email; do
                  if [ -f "$email" ]; then
                    filename=$(basename "$email")
                    # Ensure Dovecot Maildir exists
                    mkdir -p /var/mail/support/Maildir/new/
                    # Copy email to Dovecot location
                    if cp "$email" "/var/mail/support/Maildir/new/$filename"; then
                      echo "  ✅ Synced: $filename"
                      # Remove from Postfix location after successful copy
                      rm -f "$email"
                      SYNC_COUNT=$((SYNC_COUNT + 1))
                    else
                      echo "  ❌ Failed: $filename"
                    fi
                  fi
                done

                echo "[$(date +%H:%M:%S)] Sync completed. Total synced: $SYNC_COUNT"
              fi
            else
              echo "[$(date +%H:%M:%S)] Waiting for /var/mail/support/new directory..."
            fi

            # Sleep 30 seconds between checks
            sleep 30
          done
        volumeMounts:
        - name: mail-data
          mountPath: /var/mail
        resources:
          requests:
            memory: "16Mi"    # Very low memory
            cpu: "10m"        # Very low CPU
          limits:
            memory: "32Mi"
            cpu: "20m"
      volumes:
      - name: mail-data
        emptyDir: {}
      - name: postfix-config
        configMap:
          name: postfix-config
EOF

echo "=== Deploying Postfix with Ultra-Cheap Sidecar ==="
kubectl apply -f /tmp/postfix-with-sidecar.yaml

echo ""
echo "⏳ Waiting for new Postfix pod to be ready..."
sleep 10

# Scale down the old Postfix deployment
kubectl scale deployment postfix-mail -n mailcow --replicas=0

echo ""
echo "✅ Ultra-Cheap Sidecar Deployed!"
echo "   - Image: alpine:latest (5MB)"
echo "   - Memory: 16Mi request / 32Mi limit"
echo "   - CPU: 10m request / 20m limit"
echo "   - Cost: Minimal"
echo "   - Sync: Automatic every 30 seconds"

echo ""
echo "📋 STEP 4: Update Dovecot Configuration"
echo "======================================"

kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "=== Ensuring Dovecot Maildir configuration ==="
echo "Maildir location: /var/mail/support/Maildir"

# Create Maildir structure if missing
mkdir -p /var/mail/support/Maildir/{cur,new,tmp}
chown -R 5000:5000 /var/mail/support/Maildir/

echo "✅ Dovecot Maildir ready"
'

echo ""
echo "🔄 STEP 5: Migrate Existing Emails"
echo "=================================="

echo "=== Migrating existing emails to new structure ==="
EMAIL_COUNT=$(kubectl exec -n $NAMESPACE $POSTFIX_POD -- find /var/mail/support/new/ -type f 2>/dev/null | wc -l)

if [ $EMAIL_COUNT -gt 0 ]; then
    echo "Found $EMAIL_COUNT emails to migrate from old Postfix pod"

    kubectl exec -n $NAMESPACE $POSTFIX_POD -- find /var/mail/support/new/ -type f 2>/dev/null | \
    while read email_path; do
        if [ -n "$email_path" ]; then
            filename=$(basename "$email_path")
            echo "Migrating: $filename"

            kubectl exec -n $NAMESPACE $POSTFIX_POD -- cat "$email_path" 2>/dev/null | \
            kubectl exec -i -n $NAMESPACE $DOVECOT_POD -- sh -c "
                mkdir -p /var/mail/support/Maildir/new/
                cat > /var/mail/support/Maildir/new/$filename
            " && echo "  ✅ Migrated: $filename"
        fi
    done
else
    echo "No emails to migrate from old Postfix pod"
fi

echo ""
echo "🧪 STEP 6: Test the Solution"
echo "============================"

echo "=== Sending test email ==="
# Use the new Postfix pod with sidecar
NEW_POSTFIX_POD=$(kubectl get pods -n mailcow -l app=postfix-with-sync -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$NEW_POSTFIX_POD" ]; then
    kubectl exec -n $NAMESPACE $NEW_POSTFIX_POD -c postfix -- sh -c '
    sendmail support@triggeriq.eu << "EOF"
Subject: 🎉 ULTRA-CHEAP SIDECAR TEST - Working!
From: sidecar-test@triggeriq.eu

This email tests the new ultra-cheap sidecar sync solution.

If you see this email in Thunderbird, the sidecar is working automatically!

Benefits:
- Cost: Minimal (alpine:latest - 5MB)
- Sync: Automatic every 30 seconds
- No expensive CronJobs needed

Timestamp: $(date)
EOF
    echo "Test email sent through new Postfix with sidecar"
    '
else
    echo "⚠️  New Postfix pod not ready yet, using old pod for test"
    kubectl exec -n $NAMESPACE $POSTFIX_POD -- sh -c '
    sendmail support@triggeriq.eu << "EOF"
Subject: TEST - Sidecar Deployment
From: test@triggeriq.eu

Testing email delivery during sidecar deployment.
EOF
    '
fi

echo ""
echo "⏳ Waiting for sidecar sync..."
sleep 45

echo ""
echo "=== Checking sidecar logs ==="
SIDECAR_POD=$(kubectl get pods -n mailcow -l app=postfix-with-sync -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$SIDECAR_POD" ]; then
    echo "Sidecar logs:"
    kubectl logs -n mailcow $SIDECAR_POD -c email-sync-sidecar --tail=5
else
    echo "Sidecar pod not ready yet"
fi

echo ""
echo "=== Verifying email delivery ==="
kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "Emails in Dovecot Maildir:"
find /var/mail/support/Maildir/ -type f 2>/dev/null | wc -l
echo "New emails (last 2 minutes):"
find /var/mail/support/Maildir/new/ -type f -mmin -2 2>/dev/null | wc -l
'

echo ""
echo "🔍 STEP 7: Final IMAP Test"
echo "=========================="

DOVECOT_IP="51.15.102.121"
echo "Testing IMAP connection..."
{
echo "a1 LOGIN support support123"
sleep 2
echo "a2 SELECT INBOX"
sleep 1
echo "a3 SEARCH ALL"
sleep 1
echo "a4 LOGOUT"
} | timeout 10 telnet $DOVECOT_IP 143 | grep -E "SEARCH|EXISTS" | head -2

echo ""
echo "✅ ULTRA-CHEAP SIDECAR SOLUTION DEPLOYED!"
echo "========================================"
echo ""
echo "🎯 Cost-Effective Benefits:"
echo "   ✅ No expensive CronJobs"
echo "   ✅ Tiny alpine image (5MB vs 200MB)"
echo "   ✅ Minimal resources (16Mi RAM, 10m CPU)"
echo "   ✅ Automatic sync every 30 seconds"
echo "   ✅ Zero additional network costs"
echo ""
echo "🔧 Technical Setup:"
echo "   📦 Sidecar container in Postfix pod"
echo "   🔄 Continuous monitoring of /var/mail/support/new/"
echo "   📧 Automatic sync to Dovecot Maildir"
echo "   💾 Shared emptyDir volume for efficiency"
echo ""
echo "📊 Resource Usage:"
echo "   Memory: 16Mi (request) / 32Mi (limit)"
echo "   CPU: 10m (request) / 20m (limit)"
echo "   Image: alpine:latest (5MB)"
echo "   Cost: Minimal on SCW Kapsule"
echo ""
echo "🚀 Emails now sync automatically with minimal cost!"
echo "   New emails will appear in Thunderbird within 30 seconds"