#!/usr/bin/env bash
# Запускать на каждом сервере:
#   bash deploy.sh debian        (subdomain = debian.linuxmirror.host)
#   bash deploy.sh fedora
#   bash deploy.sh archlinux     и т.д.
set -euo pipefail

SUBDOMAIN="${1:?Usage: bash deploy.sh <subdomain>}"
DOMAIN="linuxmirror.host"
FQDN="${SUBDOMAIN}.${DOMAIN}"
EMAIL="mirror@${DOMAIN}"
CF_CREDS="/root/.secrets/cloudflare.ini"
MIRROR_USER="mirror"

echo "==> Deploying linuxmirror on ${FQDN}"

# ── 1. Пакеты ─────────────────────────────────────────────────────────
echo "[1/7] Installing packages..."
apt-get update -qq
apt-get install -y -qq nginx libnginx-mod-stream certbot python3-certbot-dns-cloudflare

# ── 2. Cloudflare credentials ─────────────────────────────────────────
if [ ! -f "$CF_CREDS" ]; then
    echo "[2/7] Cloudflare API token not found at $CF_CREDS"
    mkdir -p /root/.secrets
    read -rsp "  Enter Cloudflare API token: " CF_TOKEN
    echo
    echo "dns_cloudflare_api_token = ${CF_TOKEN}" > "$CF_CREDS"
    chmod 600 "$CF_CREDS"
else
    echo "[2/7] Cloudflare credentials found."
fi

# ── 3. TLS сертификат ─────────────────────────────────────────────────
echo "[3/7] Obtaining TLS certificate..."
if [ ! -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
    certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials "$CF_CREDS" \
        -d "${DOMAIN}" \
        -d "*.${DOMAIN}" \
        --email "$EMAIL" --agree-tos --non-interactive
else
    echo "  Certificate already exists, skipping."
fi

# ── 4. Статический сайт ───────────────────────────────────────────────
echo "[4/7] Deploying website files..."
mkdir -p /var/www/linuxmirror
cp "$(dirname "$0")/index.html" \
   "$(dirname "$0")/style.css" \
   "$(dirname "$0")/app.js" \
   /var/www/linuxmirror/
chown -R www-data:www-data /var/www/linuxmirror

# ── 5. nginx конфиги ──────────────────────────────────────────────────
echo "[5/7] Configuring nginx..."

# убрать дефолтный сайт
rm -f /etc/nginx/sites-enabled/default

# скопировать конфиги
cp "$(dirname "$0")/nginx/linuxmirror.conf" /etc/nginx/conf.d/linuxmirror.conf
cp "$(dirname "$0")/nginx/stream.conf"      /etc/nginx/stream.conf

# добавить stream {} блок в nginx.conf если его нет
if ! grep -q "stream {" /etc/nginx/nginx.conf; then
    echo -e "\nstream {\n    include /etc/nginx/stream.conf;\n}" >> /etc/nginx/nginx.conf
    echo "  Added stream block to nginx.conf"
fi

# ── 6. Пользователь mirror ────────────────────────────────────────────
echo "[6/7] Creating mirror user..."
if [ ! -f /etc/nginx/.htpasswd ]; then
    read -rsp "  Password for mirror user '${MIRROR_USER}': " MIRROR_PASS
    echo
    HASH=$(openssl passwd -apr1 "$MIRROR_PASS")
    echo "${MIRROR_USER}:${HASH}" > /etc/nginx/.htpasswd
    chmod 640 /etc/nginx/.htpasswd
    chown root:www-data /etc/nginx/.htpasswd
    echo "  Created /etc/nginx/.htpasswd"
else
    echo "  /etc/nginx/.htpasswd already exists, skipping."
fi

# ── 7. Запуск ─────────────────────────────────────────────────────────
echo "[7/7] Starting nginx..."
nginx -t
systemctl enable nginx
systemctl restart nginx

# ── Результат ─────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "  Done! https://${FQDN}"
echo ""
ss -tlnp | grep nginx | awk '{print "  " $4}'
echo ""
echo "  Test:"
echo "  curl -sk https://${FQDN}/ | grep -o '<title>.*</title>'"
echo "╚══════════════════════════════════════════╝"
