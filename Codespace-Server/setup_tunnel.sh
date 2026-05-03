#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# اسکریپت راه‌اندازی سرور رله روی GitHub Codespaces
# این اسکریپت Xray-core را دانلود می‌کند، یک UUID تصادفی می‌سازد، فایل پیکربندی
# VLESS بر بستر WebSocket را تولید می‌کند و سرویس را روی پورت ۸۰۸۰ اجرا می‌کند.
# -----------------------------------------------------------------------------

set -euo pipefail

# مسیر کاری — همه چیز در پوشه ~/.tbvpn-relay قرار می‌گیرد
WORK_DIR="${HOME}/.tbvpn-relay"
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

# نمایش پیام شروع به فارسی
echo "در حال راه‌اندازی سرور رله TB VPN…"

# تشخیص معماری پردازنده برای دانلود نسخه مناسب Xray
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64|amd64) XRAY_PKG="Xray-linux-64.zip" ;;
  aarch64|arm64) XRAY_PKG="Xray-linux-arm64-v8a.zip" ;;
  *)
    echo "معماری پشتیبانی نمی‌شود: ${ARCH}"
    exit 1
    ;;
esac

# دانلود آخرین نسخه Xray در صورت عدم وجود
if [[ ! -x "./xray" ]]; then
  echo "در حال دانلود Xray-core (${XRAY_PKG})…"
  LATEST_URL="$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest \
                 | grep -oE "https://[^\"]*${XRAY_PKG}" | head -n1)"
  if [[ -z "${LATEST_URL}" ]]; then
    echo "نشانی دانلود پیدا نشد — استفاده از نسخه ثابت"
    LATEST_URL="https://github.com/XTLS/Xray-core/releases/latest/download/${XRAY_PKG}"
  fi
  curl -L "${LATEST_URL}" -o xray.zip
  unzip -o xray.zip -d xray-bin >/dev/null
  cp xray-bin/xray ./xray
  chmod +x ./xray
  rm -rf xray.zip xray-bin
  echo "Xray با موفقیت نصب شد"
fi

# تولید UUID تصادفی برای کاربر VLESS
if command -v uuidgen >/dev/null 2>&1; then
  RELAY_UUID="$(uuidgen | tr 'A-Z' 'a-z')"
else
  RELAY_UUID="$(./xray uuid)"
fi

echo "شناسه یکتای رله تولید شد: ${RELAY_UUID}"
# ذخیره UUID در یک فایل برای استفاده توسط برنامه کلاینت
echo "${RELAY_UUID}" > "${WORK_DIR}/uuid.txt"

# ساخت فایل پیکربندی Xray — ورودی VLESS روی WebSocket پورت ۸۰۸۰
cat > "${WORK_DIR}/config.json" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "vless-in",
      "listen": "0.0.0.0",
      "port": 8080,
      "protocol": "vless",
      "settings": {
        "clients": [
          { "id": "${RELAY_UUID}", "level": 0 }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/",
          "headers": {
            "Host": "tbvpn.relay"
          }
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": { "domainStrategy": "UseIP" }
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ],
  "routing": {
    "rules": [
      { "type": "field", "ip": ["geoip:private"], "outboundTag": "block" }
    ]
  }
}
EOF

echo "فایل پیکربندی در ${WORK_DIR}/config.json ساخته شد"
echo "پورت گوش‌دهنده: 8080  |  مسیر WebSocket: /"

# اجرای Xray در پیش‌زمینه — Codespace آن را زنده نگه می‌دارد
echo "در حال اجرای سرور Xray…"
exec ./xray run -config "${WORK_DIR}/config.json"
