#!/usr/bin/env bash
# Деплой Flutter Web на EU backend (§8.5).
#
# Usage:
#   sudo ./scripts/deploy-web-eu.sh
#   SKIP_BUILD=1 sudo ./scripts/deploy-web-eu.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${RIOGRAM_WEB_ROOT:-/opt/riogram/web}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  "${ROOT_DIR}/scripts/build-web.sh"
fi

if [[ ! -f "${ROOT_DIR}/build/web/index.html" ]]; then
  echo "build/web/index.html not found — run ./scripts/build-web.sh" >&2
  exit 1
fi

install -d -m 755 "${DEST}"
rsync -a --delete "${ROOT_DIR}/build/web/" "${DEST}/" 2>/dev/null || {
  rm -rf "${DEST:?}/"*
  cp -a "${ROOT_DIR}/build/web/." "${DEST}/"
}

if id riogram &>/dev/null; then
  chown -R riogram:riogram "${DEST}"
fi

echo "✅ Deployed to ${DEST}/"
echo "   Verify: curl -s http://127.0.0.1:8080/ | head"
echo "   (requires riogram-eu-backend nginx + tunnel for external access)"
