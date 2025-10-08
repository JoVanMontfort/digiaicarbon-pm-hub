#!/bin/bash
echo "🚀 Applying Fixed Virtual Mailbox Configuration for triggeriq.eu"
echo ""

echo "1. Deleting current Postfix deployment..."
kubectl delete deployment postfix-mail -n mailcow --ignore-not-found=true

echo ""
echo "2. Deleting old ConfigMaps..."
kubectl delete configmap postfix-virtual-config -n mailcow --ignore-not-found=true
kubectl delete configmap postfix-startup-scripts -n mailcow --ignore-not-found=true
kubectl delete configmap virtual-mailbox-map -n mailcow --ignore-not-found=true

echo ""
echo "3. Creating ConfigMaps for triggeriq.eu..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: postfix-virtual-config
  namespace: mailcow
data:
  virtual: |
    test@triggeriq.eu test/
    admin@triggeriq.eu admin/
    info@triggeriq.eu info/
    support@triggeriq.eu support/
  main.cf.patch: |
    # Virtual mailbox configuration
    virtual_mailbox_domains = triggeriq.eu
    virtual_mailbox_base = /var/mail
    virtual_mailbox_maps = hash:/etc/postfix/virtual
    virtual_uid_maps = static:5000
    virtual_gid_maps = static:5000
    virtual_minimum_uid = 5000
    virtual_transport = virtual
    # Fix configuration conflicts
    message_size_limit = 10240000
    virtual_mailbox_limit = 10240000
    # Local delivery only
    mydestination = localhost.localdomain, localhost
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: postfix-startup-scripts
  namespace: mailcow
data:
  10-setup-virtual.sh: |
    #!/bin/bash
    echo "Setting up virtual mailboxes for triggeriq.eu..."

    # Create mail directories as root first
    mkdir -p /var/mail/test /var/mail/admin /var/mail/info /var/mail/support
    chown -R 5000:5000 /var/mail

    # Compile virtual map (creates virtual.db)
    echo "Compiling virtual map..."
    postmap /etc/postfix/virtual

    # Apply main.cf patches
    echo "Applying Postfix configuration..."
    while IFS= read -r line; do
      if [ -n "\$line" ] && [[ "\$line" != \#* ]]; then
        echo "Setting: \$line"
        postconf -e "\$line"
      fi
    done < /etc/postfix/main.cf.patch

    # Set hostname explicitly
    postconf -e "myhostname=mail.triggeriq.eu"

    echo "Virtual mailbox setup completed!"
    echo "Checking configuration..."
    postconf virtual_mailbox_maps message_size_limit virtual_mailbox_limit
EOF

echo ""
echo "4. Creating Postfix deployment with virtual mailboxes..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postfix-mail
  namespace: mailcow
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postfix-mail
  template:
    metadata:
      labels:
        app: postfix-mail
    spec:
      containers:
        - name: postfix
          image: boky/postfix:latest
          env:
            - name: ALLOWED_SENDER_DOMAINS
              value: triggeriq.eu
            - name: POSTFIX_myhostname
              value: mail.triggeriq.eu
            - name: POSTFIX_mynetworks
              value: 0.0.0.0/0
            - name: POSTFIX_inet_interfaces
              value: all
          ports:
            - containerPort: 25
            - containerPort: 587
            - containerPort: 465
          volumeMounts:
            - name: virtual-config
              mountPath: /etc/postfix/virtual
              subPath: virtual
            - name: main-cf-patch
              mountPath: /etc/postfix/main.cf.patch
              subPath: main.cf.patch
            - name: mail-data
              mountPath: /var/mail
            - name: startup-scripts
              mountPath: /docker-entrypoint.d
      volumes:
        - name: virtual-config
          configMap:
            name: postfix-virtual-config
            items:
            - key: virtual
              path: virtual
        - name: main-cf-patch
          configMap:
            name: postfix-virtual-config
            items:
            - key: main.cf.patch
              path: main.cf.patch
        - name: mail-data
          emptyDir: {}
        - name: startup-scripts
          configMap:
            name: postfix-startup-scripts
            defaultMode: 0755
EOF

echo ""
echo "5. Waiting for Postfix to start..."
sleep 30
kubectl wait --for=condition=ready pod -l app=postfix-mail -n mailcow --timeout=120s

echo ""
echo "6. Checking if virtual setup worked..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "=== Checking virtual files ==="
ls -la /etc/postfix/virtual*
echo "--- Virtual file content ---"
cat /etc/postfix/virtual
echo "--- Virtual DB file ---"
ls -la /etc/postfix/virtual.db 2>/dev/null || echo "Virtual DB not found yet"

echo "=== Checking startup script execution ==="
ls -la /docker-entrypoint.d/

echo "=== Checking mail directories ==="
ls -la /var/mail/

echo "=== Testing virtual map ==="
postmap -q "test@triggeriq.eu" hash:/etc/postfix/virtual 2>&1

echo "=== Checking Postfix config ==="
postconf myhostname
postconf virtual_mailbox_domains
postconf virtual_mailbox_maps
postconf message_size_limit virtual_mailbox_limit
'

echo ""
echo "7. Testing mail delivery..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c "
echo 'Subject: Test Virtual Mailbox
From: test@triggeriq.eu
To: test@triggeriq.eu

Testing fixed virtual mailbox delivery for triggeriq.eu' | sendmail -v test@triggeriq.eu
"

echo ""
echo "8. Checking logs for errors..."
kubectl logs -n mailcow deployment/postfix-mail --tail=20

echo ""
echo "🎉 Fixed virtual mailbox configuration for triggeriq.eu applied!"