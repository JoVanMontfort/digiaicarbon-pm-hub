#!/bin/bash
NAMESPACE="mailcow"

echo "📧 Complete Mailcow Setup Check"
echo "================================"

echo "1. All pods in mailcow namespace:"
kubectl -n $NAMESPACE get pods

echo ""
echo "2. Services in mailcow namespace:"
kubectl -n $NAMESPACE get services

echo ""
echo "3. Check for Dovecot pod:"
kubectl -n $NAMESPACE get pods | grep -i dovecot

echo ""
echo "4. Check for other mail-related pods:"
kubectl -n $NAMESPACE get pods | grep -E "(mysql|redis|nginx|rspamd|webmail)"