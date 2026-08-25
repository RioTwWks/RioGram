#!/usr/bin/env bash
# Bootstrap RioGram Web infrastructure on EU backend VPS (§8.4).
#
# Usage:
#   sudo ./scripts/setup-web-infra-eu.sh
#   # then edit /etc/riogram/web.env, deploy SSH key, start services
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

echo "==> Packages"
apt-get update
apt-get install -y nginx autossh openssh-client ufw curl

echo "==> riogram user"
if ! id riogram &>/dev/null; then
  useradd --system --create-home --home-dir /var/lib/riogram --shell /usr/sbin/nologin riogram
fi
install -d -m 700 -o riogram -g riogram /var/lib/riogram/.ssh
install -d -m 755 /opt/riogram/bin
install -d -m 755 /etc/riogram
install -d -m 755 /var/log/riogram

echo "==> Config"
if [[ ! -f /etc/riogram/web.env ]]; then
  install -m 640 "${ROOT_DIR}/deploy/env/riogram-web.env.example" /etc/riogram/web.env
  echo "Created /etc/riogram/web.env — edit before starting tunnel"
fi

install -m 644 "${ROOT_DIR}/deploy/nginx/riogram-eu-backend.conf" /etc/riogram/nginx-eu-backend.conf
install -m 755 "${ROOT_DIR}/scripts/autossh-riogram-tunnel.sh" /opt/riogram/bin/
install -m 644 "${ROOT_DIR}/deploy/systemd/riogram-eu-backend.service" /etc/systemd/system/
install -m 644 "${ROOT_DIR}/deploy/systemd/autossh-riogram-tunnel.service" /etc/systemd/system/

if [[ -x "${ROOT_DIR}/bin/riogram-wss-proxy" ]]; then
  install -m 755 "${ROOT_DIR}/bin/riogram-wss-proxy" /opt/riogram/bin/
else
  echo "⚠  bin/riogram-wss-proxy not found — run ./scripts/build-wss-proxy.sh first"
fi

if [[ ! -f /etc/systemd/system/riogram-wss-proxy.service ]]; then
  install -m 644 "${ROOT_DIR}/deploy/systemd/riogram-wss-proxy.service" /etc/systemd/system/
fi

echo "==> Placeholder static server (§8.5) on :5000 until Flutter web deploy"
cat >/etc/systemd/system/riogram-static-placeholder.service <<'UNIT'
[Unit]
Description=RioGram static web placeholder (§8.5)
After=network-online.target

[Service]
Type=simple
User=riogram
WorkingDirectory=/opt/riogram/web
ExecStart=/usr/bin/python3 -m http.server 5000 --bind 127.0.0.1
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

install -d -m 755 /opt/riogram/web
if [[ ! -f /opt/riogram/web/index.html ]]; then
  echo '<!DOCTYPE html><html><body><h1>RioGram Web</h1><p>Deploy build/web here (§8.5)</p></body></html>' \
    >/opt/riogram/web/index.html
fi
chown -R riogram:riogram /opt/riogram/web

systemctl daemon-reload
systemctl enable riogram-wss-proxy riogram-eu-backend riogram-static-placeholder

echo ""
echo "✅ EU bootstrap complete."
echo ""
echo "Next steps:"
echo "  1. Edit /etc/riogram/web.env (TUNNEL_RU_HOST, TUNNEL_SSH_USER, domain)"
echo "  2. ssh-keygen -t ed25519 -f /var/lib/riogram/.ssh/id_ed25519 -N ''"
echo "  3. Add public key to RU tunnel user authorized_keys"
echo "  4. systemctl start riogram-wss-proxy riogram-eu-backend riogram-static-placeholder"
echo "  5. systemctl start autossh-riogram-tunnel"
echo "  6. ${ROOT_DIR}/deploy/ufw/riogram-eu.sh"
