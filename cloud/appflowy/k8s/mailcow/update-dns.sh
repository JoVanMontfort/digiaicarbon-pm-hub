#!/bin/bash

# Script to update DNS records after getting LoadBalancer IPs
SMTP_IP=$(kubectl get svc mailcow-smtp -n mailcow -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
WEB_IP=$(kubectl get svc mailcow-web -n mailcow -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

cat << EOF

📋 DNS Records to update:

Domain: damno-solutions.be

A Records:
mail.damno-solutions.be.    A     $WEB_IP
autodiscover.damno-solutions.be. A $WEB_IP
autoconfig.damno-solutions.be. A  $WEB_IP

MX Record:
damno-solutions.be.    MX  10  mail.damno-solutions.be.

TXT Records:
damno-solutions.be.    TXT  "v=spf1 mx -all"
_dmarc.damno-solutions.be. TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@damno-solutions.be"

EOF