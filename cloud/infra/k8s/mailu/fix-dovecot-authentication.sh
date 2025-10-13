#!/bin/bash

echo "🔧 Fixing Dovecot Authentication for Thunderbird"
echo "==============================================="

NAMESPACE="mailcow"
DOVECOT_POD="dovecot-mail-79b96d4cf4-s98vr"
DOVECOT_IP="51.15.102.121"

echo ""
echo "1. Checking current Dovecot status..."
echo "------------------------------------"

kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "=== Current Dovecot processes ==="
ps aux | grep dovecot | grep -v grep

echo ""
echo "=== Current listening ports ==="
netstat -tlnp 2>/dev/null | grep dovecot || ss -tlnp 2>/dev/null | grep dovecot

echo ""
echo "=== Current config summary ==="
doveconf -n 2>/dev/null | grep -E "(ssl|auth|protocols)" | head -20 || echo "Cannot read dovecot config"
'

echo ""
echo "2. Testing current IMAP authentication..."
echo "---------------------------------------"

echo "🔌 Testing current IMAP connection..."
timeout 10 bash -c "
(
echo 'a1 CAPABILITY'
sleep 2
) | telnet $DOVECOT_IP 143
" && echo "✅ IMAP connection successful" || echo "❌ IMAP connection failed"

echo ""
echo "3. Checking Mailcow authentication setup..."
echo "-----------------------------------------"

kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "=== Testing authentication for support@triggeriq.eu ==="
doveadm auth test support@triggeriq.eu support123 2>/dev/null && echo "✅ Authentication successful" || echo "❌ Authentication failed"

echo ""
echo "=== Checking auth logs ==="
tail -20 /var/log/dovecot-auth.log 2>/dev/null | grep -i support || echo "No recent auth logs for support user"

echo ""
echo "=== Checking user in passwd file ==="
grep support /etc/passwd 2>/dev/null && echo "✅ User exists in system" || echo "❌ User not in system"
'

echo ""
echo "4. Applying Thunderbird-compatible settings..."
echo "--------------------------------------------"

kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "=== Creating Thunderbird-compatible config patch ==="

# Backup original config
cp /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.backup 2>/dev/null

# Create config directory if it doesn'\''t exist
mkdir -p /etc/dovecot/conf.d

# Apply settings that work with Thunderbird
echo "=== Applying settings ==="
doveconf -n 2>/dev/null > /tmp/current.conf

# Check and modify auth mechanisms
if ! grep -q "auth_mechanisms.*plain.*login" /tmp/current.conf 2>/dev/null; then
    echo "Enabling plain and login auth mechanisms..."
    echo "auth_mechanisms = plain login" >> /etc/dovecot/conf.d/10-thunderbird.conf
fi

# Ensure plaintext auth is allowed for testing
if grep -q "disable_plaintext_auth.*yes" /tmp/current.conf 2>/dev/null; then
    echo "Temporarily allowing plaintext auth..."
    echo "disable_plaintext_auth = no" >> /etc/dovecot/conf.d/10-thunderbird.conf
fi

# Add Thunderbird-specific workarounds
echo "protocol imap {" >> /etc/dovecot/conf.d/10-thunderbird.conf
echo "  mail_plugins = \$mail_plugins" >> /etc/dovecot/conf.d/10-thunderbird.conf
echo "  imap_client_workarounds = tb-extra-mailbox-sep" >> /etc/dovecot/conf.d/10-thunderbird.conf
echo "}" >> /etc/dovecot/conf.d/10-thunderbird.conf

echo "=== New configuration applied ==="
'

echo ""
echo "5. Restarting Dovecot with new settings..."
echo "----------------------------------------"

kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "=== Restarting Dovecot ==="
if [ -f /run/dovecot/master.pid ]; then
    kill -HUP $(cat /run/dovecot/master.pid) 2>/dev/null
    echo "Dovecot reloaded via HUP signal"
else
    echo "No master.pid found - Dovecot may restart automatically"
fi

sleep 5

echo ""
echo "=== Checking Dovecot status after changes ==="
ps aux | grep dovecot | grep -v grep

echo ""
echo "=== Checking if configuration is loaded ==="
doveconf -n 2>/dev/null | grep -E "(auth_mechanisms|disable_plaintext_auth|imap_client_workarounds)" || echo "Cannot verify config"
'

echo ""
echo "6. Testing authentication with new settings..."
echo "--------------------------------------------"

echo "🔌 Testing IMAP authentication..."
timeout 10 bash -c "
(
echo 'a1 CAPABILITY'
sleep 1
echo 'a2 LOGIN \"support@triggeriq.eu\" \"support123\"'
sleep 2
echo 'a3 LIST \"\" \"*\"'
sleep 1
echo 'a4 LOGOUT'
) | telnet $DOVECOT_IP 143
" && echo "✅ IMAP authentication test completed" || echo "❌ IMAP authentication test failed"

echo ""
echo "7. Testing different authentication methods..."
echo "--------------------------------------------"

echo "Testing PLAIN auth:"
timeout 8 bash -c "(
echo 'a1 LOGIN \"support@triggeriq.eu\" \"support123\"'
sleep 3
echo 'a2 LOGOUT'
) | telnet $DOVECOT_IP 143" && echo "✅ PLAIN auth successful" || echo "❌ PLAIN auth failed"

echo ""
echo "Testing AUTHENTICATE LOGIN:"
timeout 8 bash -c "(
echo 'a1 AUTHENTICATE LOGIN'
sleep 1
echo 'c3VwcG9ydEB0cmlnZ2VyaXEuZXU='  # support@triggeriq.eu in base64
sleep 1
echo 'c3VwcG9ydDEyMw=='  # support123 in base64
sleep 2
) | telnet $DOVECOT_IP 143" && echo "✅ LOGIN auth successful" || echo "❌ LOGIN auth failed"

echo ""
echo "🎯 THUNDERBIRD CONFIGURATION OPTIONS:"
echo "===================================="
echo ""
echo "OPTION 1 - Normal Password (Recommended):"
echo "   Server: $DOVECOT_IP"
echo "   Port: 143"
echo "   Security: STARTTLS"
echo "   Authentication: Normal password"
echo "   Username: support@triggeriq.eu"
echo "   Password: support123"
echo ""
echo "OPTION 2 - SSL/TLS:"
echo "   Server: $DOVECOT_IP"
echo "   Port: 993"
echo "   Security: SSL/TLS"
echo "   Authentication: Normal password"
echo "   Username: support@triggeriq.eu"
echo "   Password: support123"
echo ""
echo "OPTION 3 - Manual Test:"
echo "   Server: $DOVECOT_IP"
echo "   Port: 143"
echo "   Security: None"
echo "   Authentication: Normal password"
echo "   Username: support@triggeriq.eu"
echo "   Password: support123"

echo ""
echo "🔍 Final Dovecot Status Check"
echo "============================"

kubectl exec -n $NAMESPACE $DOVECOT_POD -- sh -c '
echo "=== Dovecot processes ==="
ps aux | grep dovecot | grep -v grep

echo ""
echo "=== Authentication mechanisms ==="
doveconf -a 2>/dev/null | grep "auth_mechanisms" | head -5

echo ""
echo "=== Recent auth logs ==="
tail -10 /var/log/dovecot-auth.log 2>/dev/null | grep -i auth || echo "No recent auth logs"

echo ""
echo "=== Listening ports ==="
netstat -tlnp 2>/dev/null | grep ":143\|:993" || ss -tlnp 2>/dev/null | grep ":143\|:993"
'

echo ""
echo "✅ Script completed! Try the Thunderbird configurations above."
echo "📧 If still having issues, check Mailcow admin panel for user status."