#!/bin/bash

echo "🚀 Applying Fixed Virtual Mailbox Configuration"

echo ""
echo "1. Deleting current Postfix deployment..."
kubectl delete deployment postfix-mail -n mailcow --ignore-not-found=true

echo ""
echo "2. Creating ConfigMaps..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: postfix-virtual-config
  namespace: mailcow
data:
  virtual: |
    test@damno-solutions.be test/
    admin@damno-solutions.be admin/
    jo.vanmontfort@damno-solutions.be jo/
    amanda.gaviriagoyes@damno-solutions.be amanda/
  main.cf.patch: |
    mydestination = localhost.localdomain, localhost, damno-solutions.be
    virtual_mailbox_domains = damno-solutions.be
    virtual_mailbox_base = /var/mail
    virtual_mailbox_maps = hash:/etc/postfix/virtual
    virtual_uid_maps = static:5000
    virtual_gid_maps = static:5000
    virtual_minimum_uid = 5000
    virtual_transport = virtual
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: postfix-startup-scripts
  namespace: mailcow
data:
  10-setup-virtual.sh: |
    #!/bin/bash
    echo "Setting up virtual mailboxes..."

    # Create mail directories
    mkdir -p /var/mail/test /var/mail/admin /var/mail/jo /var/mail/amanda
    chown -R 5000:5000 /var/mail

    # Compile virtual map
    postmap /etc/postfix/virtual

    # Apply main.cf patches
    while IFS= read -r line; do
      if [ -n "$line" ]; then
        postconf -e "\$line"
      fi
    done < <(grep -v '^#' /etc/postfix/main.cf.patch 2>/dev/null || echo "")

    echo "Virtual mailbox setup completed!"
EOF

echo ""
echo "3. Creating Postfix deployment with virtual mailboxes..."
kubectl apply -f - <<EOF
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
              value: damno-solutions.be
            - name: POSTFIX_myhostname
              value: mail.damno-solutions.be
            - name: POSTFIX_mynetworks
              value: 0.0.0.0/0
            - name: POSTFIX_inet_interfaces
              value: all
            - name: RELAYHOST
              value: ""
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
          persistentVolumeClaim:
            claimName: mailcow-data
        - name: startup-scripts
          configMap:
            name: postfix-startup-scripts
            defaultMode: 0755
EOF

echo ""
echo "4. Waiting for Postfix to start..."
sleep 45

echo ""
echo "5. Checking if virtual setup worked..."
kubectl exec -it deployment/postfix-mail -n mailcow -- sh -c '
echo "Checking virtual files:"
ls -la /etc/postfix/virtual*
cat /etc/postfix/virtual

echo "Checking startup script:"
ls -la /docker-entrypoint.d/

echo "Checking mail directories:"
ls -la /var/mail/

echo "Testing virtual map:"
postmap -q "test@damno-solutions.be" hash:/etc/postfix/virtual 2>&1
'

echo ""
echo "6. Testing mail delivery..."
swaks --to test@damno-solutions.be --from test@damno-solutions.be \
  --server 51.158.216.249 --body "Testing fixed virtual mailbox delivery" \
  --h-Subject "Fixed Virtual Test"

echo ""
echo "🎉 Fixed virtual mailbox configuration applied!"