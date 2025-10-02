#!/bin/bash

POSTFIX_IP="51.158.216.249"
DOVECOT_IP="51.15.102.121"

echo "📧 Testing with new LoadBalancer IPs"

echo ""
echo "1. Testing SMTP on new IP ($POSTFIX_IP):"
{
  sleep 2
  echo "EHLO test.damno-solutions.be"
  sleep 2
  echo "QUIT"
} | telnet $POSTFIX_IP 25

echo ""
echo "2. Testing SMTP Submission (587) on new IP:"
{
  sleep 2
  echo "EHLO test.damno-solutions.be"
  sleep 2
  echo "QUIT"
} | telnet $POSTFIX_IP 587

echo ""
echo "3. Testing IMAPS on Dovecot IP ($DOVECOT_IP):"
timeout 10 openssl s_client -connect $DOVECOT_IP:993 -quiet <<EOF
A01 LOGIN test password
EOF

echo ""
echo "✅ Testing completed - Note the different IPs for SMTP vs IMAP"