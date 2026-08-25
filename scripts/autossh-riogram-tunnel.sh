#!/usr/bin/env bash
# Start autossh reverse tunnel using /etc/riogram/web.env (§8.4).
set -euo pipefail

ENV_FILE="${RIOGRAM_ENV_FILE:-/etc/riogram/web.env}"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}" >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "${ENV_FILE}"
set +a

: "${TUNNEL_SSH_USER:?TUNNEL_SSH_USER required}"
: "${TUNNEL_RU_HOST:?TUNNEL_RU_HOST required}"
: "${TUNNEL_RU_PORT:?TUNNEL_RU_PORT required}"
: "${TUNNEL_EU_PORT:?TUNNEL_EU_PORT required}"

TUNNEL_RU_BIND="${TUNNEL_RU_BIND:-127.0.0.1}"
IDENTITY="${TUNNEL_IDENTITY_FILE:-/var/lib/riogram/.ssh/id_ed25519}"

exec /usr/bin/autossh -M 0 -N \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o ExitOnForwardFailure=yes \
  -o StrictHostKeyChecking=accept-new \
  -o IdentityFile="${IDENTITY}" \
  -R "${TUNNEL_RU_BIND}:${TUNNEL_RU_PORT}:127.0.0.1:${TUNNEL_EU_PORT}" \
  "${TUNNEL_SSH_USER}@${TUNNEL_RU_HOST}"
