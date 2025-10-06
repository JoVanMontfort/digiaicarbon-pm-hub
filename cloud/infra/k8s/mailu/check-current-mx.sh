#!/bin/bash
echo "🔍 Checking Current MX Records"
echo "============================"

DOMAINS=("triggeriq.eu")

for domain in "${DOMAINS[@]}"; do
    echo ""
    echo "=== $domain ==="
    echo "MX records:"
    dig MX $domain +short
    echo "A record for mail server:"
    dig A mail.$domain +short
done

echo ""
echo "For incoming mail, MX records should point to: 51.158.216.249"