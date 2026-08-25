#!/usr/bin/env bash
# Bootstrap RioGram Web infrastructure on RU frontend VPS (§8.4).
#
# Usage:
#   sudo RIOGRAM_DOMAIN=your-domain.ru ./scripts/setup-web-infra-ru.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAIN="${RIOGRAM_DOMAIN:-}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo RIOGRAM_DOMAIN=... $0" >&2
  exit 1
fi

if [[ -z "${DOMAIN}" ]]; then
  echo "Set RIOGRAM_DOMAIN=your-domain.ru" >&2
  exit 1
fi

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

echo "==> Nginx"
install -d -m 755 /var/www/certbot
sed "s/__RIOGRAM_DOMAIN__/${DOMAIN}/g" \
  "${ROOT_DIR}/deploy/nginx/riogram-ru.conf.template" \
  >/etc/nginx/sites-available/riogram

ln -sf /etc/nginx/sites-available/riogram /etc/nginx/sites-enabled/riogram
rm -f /etc/nginx/sites-enabled/default

if ! nginx -t; then
  echo "Nginx config test failed (SSL paths missing until certbot runs)" >&2
  echo "Run certbot after DNS is ready:" >&2
  echo "  certbot --nginx -d ${DOMAIN} --email you@example.com --agree-tos" >&2
else
  systemctl reload nginx
fi

echo ""
echo "✅ RU bootstrap complete for ${DOMAIN}"
echo ""
echo "Next steps:"
echo "  1. Add EU tunnel public key to /var/lib/riogram-tunnel/.ssh/authorized_keys"
echo "  2. DNS A-record ${DOMAIN} → this server"
echo "  3. certbot --nginx -d ${DOMAIN}"
echo "  4. ${ROOT_DIR}/deploy/ufw/riogram-ru.sh"
echo "  5. From RU: curl http://127.0.0.1:8080/health  (after EU tunnel is up)"
