#!/usr/bin/env bash
# Деплой Flutter Web на EU backend (§8.5).
#
# Usage:
#   ./scripts/build-web.sh && sudo ./scripts/deploy-web-eu.sh
#   sudo env SKIP_BUILD=1 ./scripts/deploy-web-eu.sh   # deploy existing build/web only
#   sudo env SKIP_TDWEB_CHECK=1 ./scripts/deploy-web-eu.sh
# Note: `VAR=1 sudo ./script` does NOT pass VAR — use `sudo env VAR=1 ./script`.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${RIOGRAM_WEB_ROOT:-/opt/riogram/web}"

# shellcheck source=lib/web-env.sh
source "${ROOT_DIR}/scripts/lib/web-env.sh"
VERIFY_BASE="$(riogram_eu_backend_base)"

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

# worker-loader expects tdweb chunks at site root (not only /tdweb/).
if [[ -d "${DEST}/tdweb" ]]; then
  for pattern in '*.worker.js' '*.wasm' '*.mem'; do
    for f in "${DEST}/tdweb"/${pattern}; do
      [[ -f "${f}" ]] || continue
      cp -f "${f}" "${DEST}/"
    done
  done
fi

# copy-tdweb may overwrite root workers with unpatched copies — re-apply WSS hook.
if compgen -G "${DEST}/*.worker.js" >/dev/null; then
  "${ROOT_DIR}/scripts/patch-tdweb-worker-wss.sh" "${DEST}"
fi

if id riogram &>/dev/null; then
  chown -R riogram:riogram "${DEST}"
fi

echo "✅ Deployed to ${DEST}/"
echo "   Verify: curl -s ${VERIFY_BASE}/ | head"
echo "           ${ROOT_DIR}/scripts/verify-web-deploy.sh"
echo "   (requires riogram-eu-backend nginx + tunnel for external access)"
