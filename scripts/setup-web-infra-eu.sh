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
  install -m 640 -g riogram "${ROOT_DIR}/deploy/env/riogram-web.env.example" /etc/riogram/web.env
  echo "Created /etc/riogram/web.env — edit before starting tunnel"
else
  chown root:riogram /etc/riogram/web.env
  chmod 640 /etc/riogram/web.env
fi

# Prefer env override, else value from web.env, else 8080.
if [[ -z "${EU_BACKEND_PORT:-}" && -f /etc/riogram/web.env ]]; then
  # shellcheck disable=SC1091
  set -a
  # shellcheck source=/dev/null
  source /etc/riogram/web.env
  set +a
fi
EU_BACKEND_PORT="${EU_BACKEND_PORT:-8080}"
if ! [[ "${EU_BACKEND_PORT}" =~ ^[0-9]+$ ]] || (( EU_BACKEND_PORT < 1 || EU_BACKEND_PORT > 65535 )); then
  echo "EU_BACKEND_PORT must be an integer 1–65535 (got: ${EU_BACKEND_PORT})" >&2
  exit 1
fi

# Keep tunnel target in sync with nginx listen.
if grep -q '^TUNNEL_EU_PORT=' /etc/riogram/web.env; then
  sed -i "s/^TUNNEL_EU_PORT=.*/TUNNEL_EU_PORT=${EU_BACKEND_PORT}/" /etc/riogram/web.env
else
  printf '\nTUNNEL_EU_PORT=%s\n' "${EU_BACKEND_PORT}" >>/etc/riogram/web.env
fi
if grep -q '^EU_BACKEND_PORT=' /etc/riogram/web.env; then
  sed -i "s/^EU_BACKEND_PORT=.*/EU_BACKEND_PORT=${EU_BACKEND_PORT}/" /etc/riogram/web.env
else
  printf 'EU_BACKEND_PORT=%s\n' "${EU_BACKEND_PORT}" >>/etc/riogram/web.env
fi

echo "==> Nginx EU backend (127.0.0.1:${EU_BACKEND_PORT})"
sed -e "s/__EU_BACKEND_PORT__/${EU_BACKEND_PORT}/g" \
  "${ROOT_DIR}/deploy/nginx/riogram-eu-backend.conf" \
  >/etc/riogram/nginx-eu-backend.conf

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
echo "     EU backend listen: 127.0.0.1:${EU_BACKEND_PORT} (set EU_BACKEND_PORT if 8080 is busy)"
echo "  2. ssh-keygen -t ed25519 -f /var/lib/riogram/.ssh/id_ed25519 -N ''"
echo "  3. Add public key to RU tunnel user authorized_keys"
echo "  4. systemctl start riogram-wss-proxy riogram-eu-backend"
echo "  5. sudo ${ROOT_DIR}/scripts/deploy-web-eu.sh"
echo "  6. systemctl start autossh-riogram-tunnel"
echo "  7. ${ROOT_DIR}/deploy/ufw/riogram-eu.sh"
echo "  8. Local check: curl -s http://127.0.0.1:${EU_BACKEND_PORT}/health"
