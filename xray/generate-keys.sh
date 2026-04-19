#!/usr/bin/env bash
# Генерирует ключи для одного сервера.
# Запускать отдельно для каждого из 6 серверов.
# Требует: xray binary в PATH или docker.
set -euo pipefail

SERVER="${1:-s1}"
DOMAIN="linuxmirror.host"
OUT="keys-${SERVER}.txt"

echo "Generating keys for ${SERVER}.${DOMAIN} ..."

# UUID для клиента (одинаковый на всех серверах — клиент использует один конфиг)
UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)

# Reality keypair
if command -v xray &>/dev/null; then
    KEYPAIR=$(xray x25519)
elif docker ps &>/dev/null; then
    KEYPAIR=$(docker run --rm teddysun/xray xray x25519)
else
    echo "xray not found. Install xray or docker."
    exit 1
fi

PRIVATE_KEY=$(echo "$KEYPAIR" | grep "Private key:" | awk '{print $3}')
PUBLIC_KEY=$(echo  "$KEYPAIR" | grep "Public key:"  | awk '{print $3}')

# ShortId — 8 случайных hex-байт
SHORT_ID=$(openssl rand -hex 8)

cat > "$OUT" <<EOF
Server:      ${SERVER}.${DOMAIN}
UUID:        ${UUID}
PrivateKey:  ${PRIVATE_KEY}
PublicKey:   ${PUBLIC_KEY}
ShortId:     ${SHORT_ID}
EOF

echo ""
echo "Saved to $OUT"
echo ""
cat "$OUT"
echo ""
echo "Client share link (v2rayN / Shadowrocket / etc.):"
echo "vless://${UUID}@${SERVER}.${DOMAIN}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SERVER}.${DOMAIN}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#${SERVER}"
