#!/usr/bin/env bash
# Generate keys for all 6 inbounds and patch config-bridge.json
# Usage: bash xray/generate-bridge-keys.sh
set -euo pipefail

CONFIG="$(dirname "$0")/config-bridge.json"
OUT="$(dirname "$0")/bridge-keys.txt"

SUBDOMAINS=(ubuntu debian fedora archlinux nixos opensuse)
UUID=$(xray uuid)

echo "UUID (shared): ${UUID}" > "$OUT"
echo "" >> "$OUT"

cp "$CONFIG" "${CONFIG}.bak"
sed -i "s/REPLACE_UUID/${UUID}/g" "$CONFIG"

for i in "${!SUBDOMAINS[@]}"; do
    N=$((i + 1))
    SUB="${SUBDOMAINS[$i]}"

    KEYS=$(xray x25519)
    PRIV=$(echo "$KEYS" | awk '/Private key:/ {print $3}')
    PUB=$(echo  "$KEYS" | awk '/Public key:/  {print $3}')
    SHORT=$(openssl rand -hex 4)

    sed -i "s/REPLACE_PRIVATE_KEY_${N}/${PRIV}/" "$CONFIG"
    sed -i "s/REPLACE_SHORT_ID_${N}/${SHORT}/"   "$CONFIG"

    echo "=== ${SUB}.linuxmirror.host (port 305${N}) ===" >> "$OUT"
    echo "PrivateKey : ${PRIV}"  >> "$OUT"
    echo "PublicKey  : ${PUB}"   >> "$OUT"
    echo "ShortId    : ${SHORT}" >> "$OUT"
    echo "vless://${UUID}@<RU_BRIDGE_IP>:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SUB}.linuxmirror.host&fp=chrome&pbk=${PUB}&sid=${SHORT}&type=tcp&headerType=none#bridge-${SUB}" >> "$OUT"
    echo "" >> "$OUT"
done

echo "Done. Keys saved to ${OUT}"
echo "Config patched: ${CONFIG}"
