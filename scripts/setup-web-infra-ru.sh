#!/usr/bin/env bash
# Bootstrap RioGram Web infrastructure on RU frontend VPS (§8.4).
#
# Usage:
#   sudo RIOGRAM_DOMAIN=your-domain.ru ./scripts/setup-web-infra-ru.sh
#   sudo RIOGRAM_DOMAIN=your-domain.ru RIOGRAM_HTTPS_PORT=16443 ./scripts/setup-web-infra-ru.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAIN="${RIOGRAM_DOMAIN:-}"
HTTPS_PORT="${RIOGRAM_HTTPS_PORT:-443}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo RIOGRAM_DOMAIN=... $0" >&2
  exit 1
fi

if [[ -z "${DOMAIN}" ]]; then
  echo "Set RIOGRAM_DOMAIN=your-domain.ru" >&2
  exit 1
fi

if ! [[ "${HTTPS_PORT}" =~ ^[0-9]+$ ]] || (( HTTPS_PORT < 1 || HTTPS_PORT > 65535 )); then
  echo "RIOGRAM_HTTPS_PORT must be an integer 1–65535 (got: ${HTTPS_PORT})" >&2
  exit 1
fi

# Empty for default 443 so browsers omit the port; otherwise ":PORT".
HTTPS_PORT_SUFFIX=""
if [[ "${HTTPS_PORT}" != "443" ]]; then
  HTTPS_PORT_SUFFIX=":${HTTPS_PORT}"
fi

PUBLIC_BASE="https://${DOMAIN}${HTTPS_PORT_SUFFIX}"
WSS_BASE="wss://${DOMAIN}${HTTPS_PORT_SUFFIX}"

echo "==> Packages"
apt-get update
apt-get install -y nginx certbot python3-certbot-nginx ufw curl

echo "==> Tunnel user"
if ! id tunnel &>/dev/null; then
  useradd --system --home-dir /var/lib/riogram-tunnel --shell /usr/sbin/nologin tunnel
fi
install -d -m 700 -o tunnel -g tunnel /var/lib/riogram-tunnel/.ssh
touch /var/lib/riogram-tunnel/.ssh/authorized_keys
chmod 600 /var/lib/riogram-tunnel/.ssh/authorized_keys
chown tunnel:tunnel /var/lib/riogram-tunnel/.ssh/authorized_keys

echo "==> sshd GatewayPorts"
SSHD_SNIPPET="/etc/ssh/sshd_config.d/riogram-gatewayports.conf"
if [[ ! -f "${SSHD_SNIPPET}" ]]; then
  install -m 644 "${ROOT_DIR}/deploy/ssh/sshd-gatewayports-snippet.conf" "${SSHD_SNIPPET}"
  systemctl reload ssh || systemctl reload sshd
fi

echo "==> Nginx (HTTPS :${HTTPS_PORT})"
install -d -m 755 /var/www/certbot
sed \
  -e "s/__RIOGRAM_DOMAIN__/${DOMAIN}/g" \
  -e "s/__RIOGRAM_HTTPS_PORT__/${HTTPS_PORT}/g" \
  -e "s/__RIOGRAM_HTTPS_PORT_SUFFIX__/${HTTPS_PORT_SUFFIX}/g" \
  "${ROOT_DIR}/deploy/nginx/riogram-ru.conf.template" \
  >/etc/nginx/sites-available/riogram

ln -sf /etc/nginx/sites-available/riogram /etc/nginx/sites-enabled/riogram
rm -f /etc/nginx/sites-enabled/default

# Persist port for UFW / ops
install -d -m 755 /etc/riogram
if [[ -f /etc/riogram/web.env ]]; then
  if grep -q '^RIOGRAM_HTTPS_PORT=' /etc/riogram/web.env; then
    sed -i "s/^RIOGRAM_HTTPS_PORT=.*/RIOGRAM_HTTPS_PORT=${HTTPS_PORT}/" /etc/riogram/web.env
  else
    printf '\nRIOGRAM_HTTPS_PORT=%s\n' "${HTTPS_PORT}" >>/etc/riogram/web.env
  fi
  if grep -q '^RIOGRAM_DOMAIN=' /etc/riogram/web.env; then
    sed -i "s/^RIOGRAM_DOMAIN=.*/RIOGRAM_DOMAIN=${DOMAIN}/" /etc/riogram/web.env
  else
    printf 'RIOGRAM_DOMAIN=%s\n' "${DOMAIN}" >>/etc/riogram/web.env
  fi
else
  cat >/etc/riogram/web.env <<EOF
RIOGRAM_DOMAIN=${DOMAIN}
RIOGRAM_HTTPS_PORT=${HTTPS_PORT}
EOF
  chmod 640 /etc/riogram/web.env
fi

if ! nginx -t; then
  echo "Nginx config test failed (SSL paths missing until certbot runs)" >&2
  echo "Issue certificate (webroot works with any HTTPS listen port):" >&2
  echo "  certbot certonly --webroot -w /var/www/certbot -d ${DOMAIN} --email you@example.com --agree-tos" >&2
  echo "  nginx -t && systemctl reload nginx" >&2
else
  systemctl reload nginx
fi

echo ""
echo "✅ RU bootstrap complete for ${DOMAIN} (HTTPS :${HTTPS_PORT})"
echo ""
echo "Next steps:"
echo "  1. Add EU tunnel public key to /var/lib/riogram-tunnel/.ssh/authorized_keys"
echo "  2. DNS A-record ${DOMAIN} → this server"
echo "  3. certbot certonly --webroot -w /var/www/certbot -d ${DOMAIN}"
echo "     then: nginx -t && systemctl reload nginx"
echo "  4. RIOGRAM_HTTPS_PORT=${HTTPS_PORT} ${ROOT_DIR}/deploy/ufw/riogram-ru.sh"
echo "  5. From RU: curl http://127.0.0.1:8080/health  (after EU tunnel is up)"
echo "  6. Open ${PUBLIC_BASE}/  |  WSS proxy base: ${WSS_BASE}"
