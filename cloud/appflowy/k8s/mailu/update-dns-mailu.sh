#!/bin/bash

echo "🌐 Advanced DNS Configuration Helper"

# Get all available IPs
POSTFIX_IP=$(kubectl get svc postfix-direct -n mailcow -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
DOVECOT_IP=$(kubectl get svc dovecot-direct -n mailcow -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
MAILU_IP=$(kubectl get svc mailu-front -n mailcow -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

echo ""
echo "Available LoadBalancer IPs:"
[ -n "$POSTFIX_IP" ] && echo "  Postfix (SMTP): $POSTFIX_IP"
[ -n "$DOVECOT_IP" ] && echo "  Dovecot (IMAP): $DOVECOT_IP"
[ -n "$MAILU_IP" ] && echo "  Mailu Front:    $MAILU_IP"

# Choose primary IP - prefer Postfix for SMTP delivery
if [ -n "$POSTFIX_IP" ]; then
  PRIMARY_IP="$POSTFIX_IP"
  echo "✅ Using Postfix IP ($PRIMARY_IP) as primary (best for SMTP delivery)"
elif [ -n "$MAILU_IP" ]; then
  PRIMARY_IP="$MAILU_IP"
  echo "⚠️  Using Mailu Front IP ($PRIMARY_IP) as primary"
else
  echo "❌ No external IPs found!"
  kubectl get svc -n mailcow
  exit 1
fi

cat << EOF

📋 DNS Records to Configure:

A Records:
mail.damno-solutions.be.    A     $PRIMARY_IP
autodiscover.damno-solutions.be. A $PRIMARY_IP
autoconfig.damno-solutions.be. A  $PRIMARY_IP

MX Record:
damno-solutions.be.    MX  10  mail.damno-solutions.be.

TXT Records (Email Security):
damno-solutions.be.    TXT  "v=spf1 mx -all"
_dmarc.damno-solutions.be. TXT "v=DMARC1; p=quarantine; rua=mailto:admin@damno-solutions.be"

🔧 Service Information:
- SMTP Server: ${POSTFIX_IP:-$PRIMARY_IP} (ports 25, 587, 465)
- IMAP Server: ${DOVECOT_IP:-$PRIMARY_IP} (ports 993, 995, 143)

Update these records in your domain registrar's DNS settings.
EOF