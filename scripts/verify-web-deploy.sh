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

fetch_body() {
  curl -sL --connect-timeout 3 "$@" 2>/dev/null || true
}

http_code() {
  curl -sL -o /dev/null -w '%{http_code}' --connect-timeout 3 "$@" 2>/dev/null || echo "000"
}

# Flutter web markers (case-insensitive).
has_flutter_markers() {
  local body="$1"
  echo "${body}" | grep -qiE 'flutter_bootstrap|flutter\.js|main\.dart\.js|flt-renderer|flutter-view'
}

echo "RioGram Web deploy check (${BASE})"
if [[ -z "${WEB_ROOT:-}" ]]; then
  echo "(port from EU_BACKEND_PORT/TUNNEL_EU_PORT in web.env → ${PORT})"
fi
echo ""

if [[ "$(http_code "${BASE}/")" == "000" && "$(http_code "${BASE}/health")" == "000" ]]; then
  echo "Cannot reach ${BASE}/ — is riogram-eu-backend listening?"
  echo "  ss -lptn 'sport = :${PORT}'"
  echo "  systemctl status riogram-eu-backend"
  echo "  Or: WEB_ROOT=http://127.0.0.1:<port> $0"
  exit 1
fi

echo -n "GET /index.html (Flutter bootstrap)... "
index_body="$(fetch_body "${BASE}/index.html")"
index_code="$(http_code "${BASE}/index.html")"
if [[ "${index_code}" == "200" ]] && has_flutter_markers "${index_body}"; then
  echo "OK"
elif [[ "${index_code}" == "200" ]] && echo "${index_body}" | grep -qi '<html'; then
  echo "FAIL (HTML without Flutter markers)"
  echo "  Hint: still the setup placeholder, or deploy incomplete."
  echo "  Run: sudo ./scripts/deploy-web-eu.sh"
  echo "  Preview: curl -s ${BASE}/index.html | head -n 15"
  failed=1
else
  echo "FAIL (HTTP ${index_code})"
  failed=1
fi

echo -n "GET / ... "
root_body="$(fetch_body "${BASE}/")"
root_code="$(http_code "${BASE}/")"
if [[ "${root_code}" == "200" ]] && has_flutter_markers "${root_body}"; then
  echo "OK"
elif [[ "${root_code}" == "200" ]] && has_flutter_markers "${index_body}"; then
  # index.html is Flutter, but / returned other HTML (odd nginx routing) — warn, don't fail hard
  echo "WARN (HTTP 200, no Flutter markers; index.html is OK)"
  echo "  Preview / : $(echo "${root_body}" | tr '\n' ' ' | head -c 120)"
elif [[ "${root_code}" == "200" ]]; then
  echo "FAIL (HTML without Flutter markers)"
  echo "  Preview: $(echo "${root_body}" | tr '\n' ' ' | head -c 160)"
  failed=1
else
  echo "FAIL (HTTP ${root_code})"
  failed=1
fi

echo -n "GET /js/wss_proxy_hook.js... "
code="$(http_code "${BASE}/js/wss_proxy_hook.js")"
if [[ "${code}" == "200" ]]; then
  echo "OK"
else
  echo "FAIL (HTTP ${code})"
  if [[ "${code}" == "403" ]]; then
    echo "  Hint: HTTP 403 often means another service is on this port, not RioGram."
    echo "  Check EU_BACKEND_PORT in /etc/riogram/web.env and: ss -lptn 'sport = :${PORT}'"
  elif [[ "${code}" == "404" ]]; then
    echo "  Hint: run sudo ./scripts/deploy-web-eu.sh"
  fi
  failed=1
fi

if [[ -f /opt/riogram/web/tdweb/tdweb.js ]]; then
  echo -n "GET /tdweb/tdweb.js... "
  code="$(http_code "${BASE}/tdweb/tdweb.js")"
  if [[ "${code}" == "200" ]]; then
    echo "OK"
  else
    echo "WARN (HTTP ${code})"
  fi
else
  echo "⏭  /opt/riogram/web/tdweb/tdweb.js not on this host"
  echo "   (UI loads, Telegram needs: ./scripts/build-tdweb.sh && ./scripts/copy-tdweb.sh && sudo ./scripts/deploy-web-eu.sh)"
fi

if [[ "${failed}" -ne 0 ]]; then
  echo ""
  echo "Deploy verification failed. See docs/WEB.md"
  if [[ -f /opt/riogram/web/index.html ]] && ! grep -qiE 'flutter_bootstrap|main\.dart\.js' /opt/riogram/web/index.html 2>/dev/null; then
    echo "On-disk /opt/riogram/web/index.html is not a Flutter build — deploy it:"
    echo "  cd ~/RioGram && sudo ./scripts/deploy-web-eu.sh"
  fi
  exit 1
fi

echo ""
echo "✅ Web deploy looks OK"
