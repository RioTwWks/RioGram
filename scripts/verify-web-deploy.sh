#!/usr/bin/env bash
# Проверка деплоя Flutter Web через EU backend aggregator (§8.5).
#
# Usage:
#   ./scripts/verify-web-deploy.sh
#   WEB_ROOT=http://127.0.0.1:8080 ./scripts/verify-web-deploy.sh
set -euo pipefail

BASE="${WEB_ROOT:-http://127.0.0.1:8080}"
failed=0

check_contains() {
  local name="$1"
  local url="$2"
  local needle="$3"
  echo -n "${name}... "
  body="$(curl -sf "${url}" 2>/dev/null || true)"
  if echo "${body}" | grep -q "${needle}"; then
    echo "OK"
    return 0
  fi
  echo "FAIL"
  return 1
}

echo "RioGram Web deploy check (${BASE})"
echo ""

check_contains "GET / (Flutter bootstrap)" "${BASE}/" "flutter" || failed=1
check_contains "GET /index.html" "${BASE}/index.html" "<html" || failed=1

echo -n "GET /js/wss_proxy_hook.js... "
code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE}/js/wss_proxy_hook.js")"
if [[ "${code}" == "200" ]]; then
  echo "OK"
else
  echo "FAIL (HTTP ${code})"
  failed=1
fi

if [[ -f /opt/riogram/web/tdweb/tdweb.js ]]; then
  echo -n "GET /tdweb/tdweb.js... "
  code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE}/tdweb/tdweb.js")"
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
  exit 1
fi

echo ""
echo "✅ Web deploy looks OK"
