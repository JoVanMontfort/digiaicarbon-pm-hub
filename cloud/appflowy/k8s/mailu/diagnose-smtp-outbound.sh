#!/bin/bash
echo "🔧 Diagnosing Outbound SMTP Connections"
echo "======================================"

echo "1. Testing outbound port 25 to Gmail:"
telnet alt2.gmail-smtp-in.l.google.com 25

echo ""
echo "2. Testing outbound port 25 to other mail providers:"
echo "   Testing port 25 to outlook.com..."
telnet outlook-com.olc.protection.outlook.com 25

echo ""
echo "3. Checking firewall rules:"
sudo iptables -L -n | grep -E "(25|OUTPUT)"

echo ""
echo "4. Checking if Postfix can resolve external domains:"
nslookup gmail-smtp-in.l.google.com
nslookup outlook-com.olc.protection.outlook.com

echo ""
echo "5. Checking Scaleway network settings:"
ip route show default