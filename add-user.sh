#!/usr/bin/env bash
# add-user.sh [username]   — add or update a mirror user
set -euo pipefail

HTPASSWD="nginx/.htpasswd"

USER="${1:-}"
if [ -z "$USER" ]; then
    read -rp "Username: " USER
fi

read -rsp "Password for $USER: " PASS
echo

HASH=$(openssl passwd -apr1 "$PASS")

touch "$HTPASSWD"
# Remove existing entry for this user if present, then append
grep -v "^${USER}:" "$HTPASSWD" > "$HTPASSWD.tmp" || true
echo "$USER:$HASH" >> "$HTPASSWD.tmp"
mv "$HTPASSWD.tmp" "$HTPASSWD"
chmod 600 "$HTPASSWD"

echo "User '$USER' saved. Reload nginx:"
echo "  docker compose exec nginx nginx -s reload"
