#!/bin/bash
# اسکریپت راه‌اندازی relay در Codespace
UUID=${1:-$(cat /proc/sys/kernel/random/uuid)}
echo "RELAY_UUID=$UUID"
mkdir -p /tmp/xray
cat > /tmp/xray/config.json << EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": 8080, "listen": "0.0.0.0",
    "protocol": "vless",
    "settings": { "clients": [{ "id": "$UUID", "level": 0 }], "decryption": "none" },
    "streamSettings": { "network": "ws", "wsSettings": { "path": "/" } }
  }],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF
echo "$UUID" > /tmp/xray/uuid.txt
xray run -config /tmp/xray/config.json &
echo "xray started on :8080"
