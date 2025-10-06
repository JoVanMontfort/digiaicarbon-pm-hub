#!/bin/bash
echo "🔍 Finding Correct TEM IP Address"
echo "================================"

# Test multiple resolution methods
echo "Testing DNS resolution for smtp.tem.scaleway.com:"

# Method 1: dig
echo "1. Using dig:"
dig +short smtp.tem.scaleway.com A

# Method 2: nslookup
echo ""
echo "2. Using nslookup:"
nslookup smtp.tem.scaleway.com 2>/dev/null | grep 'Address:' | tail -1

# Method 3: host
echo ""
echo "3. Using host:"
host smtp.tem.scaleway.com 2>/dev/null | grep 'has address'

# Method 4: Test known TEM IPs
echo ""
echo "4. Testing known TEM IPs:"
KNOWN_IPS=("51.159.143.147" "51.158.147.414" "51.15.197.227")
for ip in "${KNOWN_IPS[@]}"; do
    echo -n "Testing $ip:2587 - "
    timeout 2 bash -c "echo > /dev/tcp/$ip/2587" 2>/dev/null && echo "✅ OPEN" || echo "❌ CLOSED"
done