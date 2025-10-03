#!/bin/bash
echo "🎯 Testing Staging Setup: staging.damno-solutions.be"
echo "===================================================="

echo "1. DNS Resolution:"
echo "   staging.damno-solutions.be -> $(dig +short A staging.damno-solutions.be)"

echo ""
echo "2. Web Server Test (if configured):"
curl -s -I --connect-timeout 5 http://staging.damno-solutions.be 2>&1 | head -1

echo ""
echo "3. Mail Server Test:"
echo "   mail.damno-solutions.be -> $(dig +short A mail.damno-solutions.be)"
echo "   MX record -> $(dig +short MX damno-solutions.be)"

echo ""
echo "4. Complete Email Test:"
./test-external-internal-mail.sh

echo ""
echo "5. Testing from staging subdomain specifically:"
swaks --to jo.vanmontfort@damno-solutions.be \
      --from test@staging.damno-solutions.be \
      --server 51.158.216.249 \
      --h-Subject "Test from staging subdomain" \
      --body "Testing email sending from staging.damno-solutions.be"