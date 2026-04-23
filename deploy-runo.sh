#!/usr/bin/env bash
# Deploy nginx to replace Caddy on the runo panel server.
# Run as root from the repository root on the runo server.
# Usage: bash deploy-runo.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_DIR="/opt/remnawave"

echo "==> Installing nginx, certbot, ssl-cert..."
apt-get update -qq
apt-get install -y -qq nginx python3-certbot-nginx ssl-cert

echo "==> Stopping Caddy container (frees ports 80 and 443)..."
cd "$COMPOSE_DIR"
docker compose stop caddy 2>/dev/null || docker-compose stop caddy 2>/dev/null || true

echo "==> Obtaining TLS certificates..."

# mooo.com domain — needs its own cert
if [ ! -f /etc/letsencrypt/live/testing-dsajgfsdfg.mooo.com/fullchain.pem ]; then
    certbot certonly --standalone --non-interactive --agree-tos \
        --email admin@linuxmirror.host \
        -d testing-dsajgfsdfg.mooo.com
else
    echo "  Cert for testing-dsajgfsdfg.mooo.com already exists, skipping."
fi

# linuxmirror.host wildcard — covers update. and api.
if [ ! -f /etc/letsencrypt/live/linuxmirror.host/fullchain.pem ]; then
    certbot certonly --standalone --non-interactive --agree-tos \
        --email admin@linuxmirror.host \
        -d linuxmirror.host \
        -d update.linuxmirror.host \
        -d api.linuxmirror.host
else
    echo "  Cert for linuxmirror.host already exists, skipping."
fi

echo ""
echo "==> Adding runo-frontend port mapping..."
echo "  runo-frontend must be accessible at 127.0.0.1:3080."
echo "  Add this to the runo-frontend service in your docker-compose file:"
echo ""
echo "    ports:"
echo "      - \"127.0.0.1:3080:80\""
echo ""

# Try to detect if already mapped
if docker inspect runo-frontend --format '{{json .HostConfig.PortBindings}}' 2>/dev/null | grep -q "3080"; then
    echo "  Already mapped. OK."
else
    echo "  Not mapped yet. Edit the docker-compose file, then run:"
    echo "    cd $COMPOSE_DIR && docker compose up -d runo-frontend"
    echo ""
    echo "  Press Enter to continue after adding the port (or Ctrl+C to abort)..."
    read -r
fi

echo "==> Installing nginx config..."
cp "$REPO/nginx/runo.conf" /etc/nginx/conf.d/runo.conf
rm -f /etc/nginx/sites-enabled/default

echo "==> Validating nginx config..."
nginx -t

echo "==> Enabling and starting nginx..."
systemctl enable nginx
systemctl restart nginx

echo "==> Removing Caddy container..."
cd "$COMPOSE_DIR"
docker compose rm -f caddy 2>/dev/null || docker-compose rm -f caddy 2>/dev/null || true

echo ""
echo "==> Done. Verifying..."
sleep 1
echo -n "  Panel:        "; curl -sk https://testing-dsajgfsdfg.mooo.com/ -o /dev/null -w "%{http_code}\n"
echo -n "  Subscription: "; curl -sk https://update.linuxmirror.host/ -o /dev/null -w "%{http_code}\n"
echo -n "  Frontend:     "; curl -sk https://api.linuxmirror.host/ -o /dev/null -w "%{http_code}\n"
echo ""
echo "Listening ports:"
ss -tlnp | grep nginx | awk '{print "  " $4}'
