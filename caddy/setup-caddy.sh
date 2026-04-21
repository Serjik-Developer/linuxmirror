#!/usr/bin/env bash
# Запускать в папке проекта: bash caddy/setup-caddy.sh
set -euo pipefail

PASS_HASH=$(caddy hash-password --plaintext "${1:?Usage: bash caddy/setup-caddy.sh <password>}")

mkdir -p /var/www/linuxmirror
cp index.html style.css app.js /var/www/linuxmirror/

sed "s|REPLACE_HASH|${PASS_HASH}|g" caddy/Caddyfile > /etc/caddy/Caddyfile

caddy validate --config /etc/caddy/Caddyfile
systemctl reload caddy || systemctl restart caddy

echo "Done. Test:"
echo "  curl -u mirror:${1} http://127.0.0.1:8080/ubuntu/dists/noble/Release -o /dev/null -w '%{http_code}'"
