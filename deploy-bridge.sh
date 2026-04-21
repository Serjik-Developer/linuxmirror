#!/usr/bin/env bash
# Deploy SNI bridge on a fresh Russian server.
# Usage: bash deploy-bridge.sh
set -euo pipefail

echo "==> Installing nginx..."
apt-get update -qq
apt-get install -y -qq nginx libnginx-mod-stream

echo "==> Configuring stream block..."

# Remove default site
rm -f /etc/nginx/sites-enabled/default

# Write stream config
cp "$(dirname "$0")/nginx/bridge.conf" /etc/nginx/nginx.conf.d_bridge 2>/dev/null || true
cat "$(dirname "$0")/nginx/bridge.conf" > /etc/nginx/bridge-stream.conf

# Inject stream include into nginx.conf if not already there
if ! grep -q "bridge-stream.conf" /etc/nginx/nginx.conf; then
    # Remove any existing bare stream {} block first
    grep -q "stream {" /etc/nginx/nginx.conf && \
        sed -i '/^stream {/,/^}/d' /etc/nginx/nginx.conf || true

    cat >> /etc/nginx/nginx.conf <<'EOF'

stream {
    include /etc/nginx/bridge-stream.conf;
}
EOF
    echo "  Added stream block."
fi

echo "==> Validating..."
nginx -t

echo "==> Starting nginx..."
systemctl enable nginx
systemctl restart nginx

echo ""
echo "Done. Listening:"
ss -tlnp | grep nginx | awk '{print "  " $4}'
echo ""
echo "Test SNI routing:"
echo "  curl -sk --resolve ubuntu.linuxmirror.host:443:\$(curl -s ifconfig.me) https://ubuntu.linuxmirror.host/ | grep -o '<title>.*</title>'"
