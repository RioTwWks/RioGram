#!/usr/bin/env bash
# UFW rules for EU backend VPS (§8.4.4).
# Optional: restrict SSH to RU VPS IP via EU_UFW_ALLOW_SSH_FROM in web.env
set -euo pipefail

ENV_FILE="${RIOGRAM_ENV_FILE:-/etc/riogram/web.env}"
ALLOW_FROM=""

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "${ENV_FILE}"
  set +a
  ALLOW_FROM="${EU_UFW_ALLOW_SSH_FROM:-}"
fi

echo "Applying UFW rules for RioGram EU backend..."

sudo ufw default deny incoming
sudo ufw default allow outgoing

if [[ -n "${ALLOW_FROM}" ]]; then
  echo "SSH allowed only from ${ALLOW_FROM}"
  sudo ufw allow from "${ALLOW_FROM}" to any port 22 proto tcp
else
  echo "SSH allowed from anywhere (set EU_UFW_ALLOW_SSH_FROM to restrict)"
  sudo ufw allow OpenSSH
fi

# Application ports stay closed — riogram-wss-proxy and nginx bind 127.0.0.1 only.
sudo ufw --force enable
sudo ufw status verbose

echo "✅ EU UFW: SSH only; app ports NOT exposed"
