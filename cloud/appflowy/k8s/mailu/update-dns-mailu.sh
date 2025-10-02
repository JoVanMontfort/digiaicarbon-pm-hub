#!/bin/bash

echo "🌐 Getting external IP for DNS records..."

# Get the external IP
EXTERNAL_IP=$(kubectl get svc mailu-front -n mailcow -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$EXTERNAL_IP" ]; then
  echo "❌ Could not get external IP. Still provisioning?"
  kubectl get svc mailu-front -n mailcow
  exit 1
fi

cat << EOF

📋 DNS Records to update for Mailu:

Domain: damno-solutions.be

A Records:
mail.damno-solutions.be.    A     $EXTERNAL_IP
autodiscover.damno-solutions.be. A $EXTERNAL_IP
autoconfig.damno-solutions.be. A  $EXTERNAL_IP

MX Record:
damno-solutions.be.    MX  10  mail.damno-solutions.be.

TXT Records:
damno-solutions.be.    TXT  "v=spf1 mx -all"
_dmarc.damno-solutions.be. TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@damno-solutions.be"

EOF