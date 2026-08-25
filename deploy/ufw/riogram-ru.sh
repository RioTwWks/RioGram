#!/usr/bin/env bash
# UFW rules for RU frontend VPS (§8.4.4).
#
# Usage:
#   sudo ./deploy/ufw/riogram-ru.sh
#   sudo RIOGRAM_HTTPS_PORT=16443 ./deploy/ufw/riogram-ru.sh
#
# Reads RIOGRAM_HTTPS_PORT from env or /etc/riogram/web.env (default 443).
set -euo pipefail

ENV_FILE="${RIOGRAM_ENV_FILE:-/etc/riogram/web.env}"
if [[ -z "${RIOGRAM_HTTPS_PORT:-}" && -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

HTTPS_PORT="${RIOGRAM_HTTPS_PORT:-443}"

if ! [[ "${HTTPS_PORT}" =~ ^[0-9]+$ ]] || (( HTTPS_PORT < 1 || HTTPS_PORT > 65535 )); then
  echo "RIOGRAM_HTTPS_PORT must be an integer 1–65535 (got: ${HTTPS_PORT})" >&2
  exit 1
fi

echo "Applying UFW rules for RioGram RU frontend (HTTP 80 + HTTPS ${HTTPS_PORT})..."

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
# ACME HTTP-01 + optional :80 → HTTPS redirect
sudo ufw allow 80/tcp comment 'RioGram HTTP/ACME'
# Custom or default HTTPS (avoid "Nginx Full" which always opens 443)
sudo ufw allow "${HTTPS_PORT}/tcp" comment 'RioGram HTTPS'
sudo ufw --force enable
sudo ufw status verbose

echo "✅ RU UFW: SSH + 80 + ${HTTPS_PORT}"
