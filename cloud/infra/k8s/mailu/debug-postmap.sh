#!/bin/bash
NAMESPACE="mailcow"
POD="postfix-mail-7db6646f7f-vhsfm"

echo "🐛 Debugging Postmap Issue"
echo "=========================="

kubectl -n $NAMESPACE exec -it $POD -- sh -c "
echo '1. Check if sasl_passwd file exists and content:'
ls -la /etc/postfix/sasl_passwd
cat /etc/postfix/sasl_passwd

echo ''
echo '2. Check postmap version and help:'
postmap -h

echo ''
echo '3. Try postmap with verbose output:'
postmap -v /etc/postfix/sasl_passwd

echo ''
echo '4. Check if .db file was created:'
ls -la /etc/postfix/sasl_passwd*

echo ''
echo '5. Check disk space:'
df -h

echo ''
echo '6. Check file permissions:'
ls -la /etc/postfix/ | head -10
"