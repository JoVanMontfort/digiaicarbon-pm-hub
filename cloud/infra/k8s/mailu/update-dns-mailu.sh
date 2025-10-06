#!/bin/bash
echo "🔄 Fixing MX record while preserving TEM outgoing mail config..."

# Remove only the problematic MX record
scw dns record delete triggeriq.eu data="0 blackhole.tem.scaleway.com." name='' type=MX

# Add correct MX and A records for incoming mail
scw dns record add triggeriq.eu name='' type=MX data='10 mail.triggeriq.eu.' ttl=3600
scw dns record add triggeriq.eu name='mail' type=A data='51.158.216.249' ttl=3600

echo "✅ MX record fixed! TEM outgoing mail configuration preserved."
echo "📧 Incoming mail will now route to your mailcow server."