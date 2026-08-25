#!/usr/bin/env bash
# Локальная проверка WSS reverse proxy (§8.3).
#
# Использование:
#   ./scripts/test-wss-proxy.sh
#   WSS_PROXY_TEST_UPSTREAM=1 ./scripts/test-wss-proxy.sh   # + WebSocket к Telegram
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${ROOT_DIR}/bin/riogram-wss-proxy"
LISTEN="${WSS_PROXY_LISTEN:-127.0.0.1:5001}"
BASE="http://${LISTEN}"

if [[ ! -x "${BIN}" ]]; then
  "${ROOT_DIR}/scripts/build-wss-proxy.sh"
fi

cleanup() {
  if [[ -n "${PID:-}" ]] && kill -0 "${PID}" 2>/dev/null; then
    kill "${PID}" 2>/dev/null || true
    wait "${PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

WSS_PROXY_LISTEN="${LISTEN}" "${BIN}" &
PID=$!
sleep 0.5

echo -n "GET /health... "
health="$(curl -sf "${BASE}/health")"
echo OK
echo "${health}" | python3 -m json.tool >/dev/null

echo -n "GET forbidden host... "
code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE}/evil.example.com/apiws")"
if [[ "${code}" != "403" ]]; then
  echo "FAIL (HTTP ${code})"
  exit 1
fi
echo OK

if [[ "${WSS_PROXY_TEST_UPSTREAM:-0}" == "1" ]]; then
  echo -n "WebSocket via proxy to venus.web.telegram.org... "
  python3 - <<'PY'
import asyncio
import json
import os
import sys
import urllib.request

listen = os.environ.get("WSS_PROXY_LISTEN", "127.0.0.1:5001")
host, port = listen.rsplit(":", 1)
url = f"ws://{host}:{port}/venus.web.telegram.org/apiws"

async def main() -> None:
    try:
        import websockets
    except ImportError:
        print("SKIP (pip install websockets)")
        return

    async with websockets.connect(url, subprotocols=["binary"]) as ws:
        await ws.ping()

asyncio.run(main())
print("OK")
PY
fi

echo ""
echo "✅ WSS proxy smoke test passed (${LISTEN})"
