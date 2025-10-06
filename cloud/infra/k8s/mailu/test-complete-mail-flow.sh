#!/bin/bash
NAMESPACE="mailcow"
POSTFIX_POD="postfix-mail-7db6646f7f-vhsfm"
POSTFIX_IP="51.158.216.249"

echo "🎯 Testing Complete Mail Flow"
echo "============================="

echo "1. Test internal email delivery:"
swaks --to jo.vanmontfort@damno-solutions.be \
      --from test@damno-solutions.be \
      --server $POSTFIX_IP \
      --h-Subject "Internal Test After Relay Setup"

echo ""
echo "2. Test external email delivery:"
swaks --to jovm007me@gmail.com \
      --from test@damno-solutions.be \
      --server $POSTFIX_IP \
      --h-Subject "External Test After Relay Setup"

echo ""
echo "3. Check Postfix queue:"
kubectl -n $NAMESPACE exec -it $POSTFIX_POD -- postqueue -p

echo ""
echo "4. Check recent logs:"
kubectl -n $NAMESPACE logs $POSTFIX_POD --tail=10