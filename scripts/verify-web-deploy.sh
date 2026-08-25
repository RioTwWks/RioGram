#!/usr/bin/env bash
# Проверка деплоя Flutter Web через EU backend aggregator (§8.5).
#
# Usage:
#   ./scripts/verify-web-deploy.sh
#   WEB_ROOT=http://127.0.0.1:18080 ./scripts/verify-web-deploy.sh
#
# Reads EU_BACKEND_PORT / TUNNEL_EU_PORT from /etc/riogram/web.env when WEB_ROOT unset.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/web-env.sh
source "${ROOT_DIR}/scripts/lib/web-env.sh"

BASE="$(riogram_eu_backend_base)"
PORT="$(riogram_eu_backend_port)"
failed=0

check_contains() {
  local name="$1"
  local url="$2"
  local needle="$3"
  echo -n "${name}... "
  body="$(curl -sf --connect-timeout 3 "${url}" 2>/dev/null || true)"
  if echo "${body}" | grep -q "${needle}"; then
    echo "OK"
    return 0
  fi
  echo "FAIL"
  return 1
}

echo "RioGram Web deploy check (${BASE})"
if [[ -z "${WEB_ROOT:-}" ]]; then
  echo "(port from EU_BACKEND_PORT/TUNNEL_EU_PORT in web.env, default 8080 → ${PORT})"
fi
echo ""

if ! curl -sf --connect-timeout 3 "${BASE}/health" >/dev/null 2>&1 \
  && ! curl -sf --connect-timeout 3 "${BASE}/" >/dev/null 2>&1; then
  echo "Cannot reach ${BASE}/ — is riogram-eu-backend listening?"
  echo "  ss -lptn 'sport = :${PORT}'"
  echo "  systemctl status riogram-eu-backend"
  echo "  Or: WEB_ROOT=http://127.0.0.1:<port> $0"
  exit 1
fi

check_contains "GET / (Flutter bootstrap)" "${BASE}/" "flutter" || failed=1
check_contains "GET /index.html" "${BASE}/index.html" "<html" || failed=1

echo -n "GET /js/wss_proxy_hook.js... "
code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 "${BASE}/js/wss_proxy_hook.js")"
if [[ "${code}" == "200" ]]; then
  echo "OK"
else
  echo "FAIL (HTTP ${code})"
  if [[ "${code}" == "403" ]]; then
    echo "  Hint: HTTP 403 often means another service is on this port, not RioGram."
    echo "  Check EU_BACKEND_PORT in /etc/riogram/web.env and: ss -lptn 'sport = :${PORT}'"
  fi
  failed=1
fi

if [[ -f /opt/riogram/web/tdweb/tdweb.js ]]; then
  echo -n "GET /tdweb/tdweb.js... "
  code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 "${BASE}/tdweb/tdweb.js")"
  if [[ "${code}" == "200" ]]; then
    echo "OK"
  else
    echo "WARN (HTTP ${code})"
  fi
else
  echo "⏭  /opt/riogram/web/tdweb/tdweb.js not on this host"
fi

if [[ "${failed}" -ne 0 ]]; then
  echo ""
  echo "Deploy verification failed. See docs/WEB.md"
  echo "If you moved the EU port: WEB_ROOT=http://127.0.0.1:18080 $0"
  exit 1
fi

echo ""
echo "✅ Web deploy looks OK"
