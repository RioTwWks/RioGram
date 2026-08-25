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

# shellcheck source=lib/wait-for-apt.sh
source "${ROOT_DIR}/scripts/lib/wait-for-apt.sh"

echo "==> Packages"
wait_for_apt
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

echo "==> Web static root (§8.5)"
install -d -m 755 /opt/riogram/web
if [[ ! -f /opt/riogram/web/index.html ]]; then
  cat >/opt/riogram/web/index.html <<'HTML'
<!DOCTYPE html>
<html><body><h1>RioGram Web</h1>
<p>Deploy with: <code>sudo ./scripts/deploy-web-eu.sh</code></p></body></html>
HTML
fi
chown -R riogram:riogram /opt/riogram/web 2>/dev/null || true

systemctl daemon-reload
systemctl enable riogram-wss-proxy riogram-eu-backend

echo ""
echo "✅ EU bootstrap complete."
echo ""
echo "Next steps:"
echo "  1. Edit /etc/riogram/web.env (TUNNEL_RU_HOST, TUNNEL_SSH_USER, domain)"
echo "  2. ssh-keygen -t ed25519 -f /var/lib/riogram/.ssh/id_ed25519 -N ''"
echo "  3. Add public key to RU tunnel user authorized_keys"
echo "  4. systemctl start riogram-wss-proxy riogram-eu-backend"
echo "  5. sudo ${ROOT_DIR}/scripts/deploy-web-eu.sh"
echo "  6. systemctl start autossh-riogram-tunnel"
echo "  7. ${ROOT_DIR}/deploy/ufw/riogram-eu.sh"
