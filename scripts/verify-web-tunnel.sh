#!/usr/bin/env bash
# Verify SSH tunnel and WSS path from RU frontend (§8.4).
#
# Usage (on RU VPS):
#   ./scripts/verify-web-tunnel.sh
#   TUNNEL_LOCAL_PORT=8080 ./scripts/verify-web-tunnel.sh
set -euo pipefail

PORT="${TUNNEL_LOCAL_PORT:-8080}"
BASE="http://127.0.0.1:${PORT}"

failed=0

check() {
  local name="$1"
  local url="$2"
  local expect="${3:-200}"
  echo -n "${name}... "
  code="$(curl -s -o /tmp/riogram-tunnel-check.out -w '%{http_code}' "${url}" || true)"
  if [[ "${code}" == "${expect}" ]]; then
    echo "OK (HTTP ${code})"
    return 0
  fi
  echo "FAIL (HTTP ${code})"
  head -c 200 /tmp/riogram-tunnel-check.out 2>/dev/null || true
  echo ""
  return 1
}

echo "RioGram tunnel verification (127.0.0.1:${PORT})"
echo ""

if ! timeout 2 bash -c "echo >/dev/tcp/127.0.0.1/${PORT}" 2>/dev/null; then
  echo "❌ Port ${PORT} is not listening on localhost."
  echo "   Check: systemctl status autossh-riogram-tunnel (EU)"
  echo "         ps aux | grep 'ssh.*-R.*${PORT}'"
  exit 1
fi

check "GET /health" "${BASE}/health" 200 || failed=1

# Telegram WSS path should reach wss-proxy (403 on GET without upgrade is OK for some paths,
# but our proxy returns normal HTTP responses for non-WS on telegram paths)
echo -n "GET /venus.web.telegram.org/apiws (HTTP probe)... "
code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE}/venus.web.telegram.org/apiws" || true)"
if [[ "${code}" =~ ^(400|403|426|502|200)$ ]]; then
  echo "OK (HTTP ${code})"
else
  echo "WARN (HTTP ${code}) — tunnel reaches backend but response unexpected"
fi

if [[ "${failed}" -ne 0 ]]; then
  echo ""
  echo "Tunnel check failed. See docs/WEB_INFRA.md troubleshooting."
  exit 1
fi

echo ""
echo "✅ Tunnel is up — backend /health reachable via 127.0.0.1:${PORT}"
