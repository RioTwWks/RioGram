#!/usr/bin/env bash
# Проверка публичного WSS endpoint через RU → tunnel → EU (после деплоя §8.3–8.4).
#
# Usage:
#   ./scripts/verify-wss-public.sh
#   WSS_BASE_URL=https://rio2skadi.ru ./scripts/verify-wss-public.sh
set -euo pipefail

BASE="${WSS_BASE_URL:-https://rio2skadi.ru}"
PATH_WS="/venus.web.telegram.org/apiws"
WSS_URL="wss://${BASE#https://}${PATH_WS}"

echo "RioGram public WSS check: ${BASE}${PATH_WS}"
echo ""

echo -n "GET /health... "
health_code="$(curl -sS -o /tmp/riogram-health.json -w '%{http_code}' "${BASE}/health")"
if [[ "${health_code}" != "200" ]]; then
  echo "FAIL (HTTP ${health_code})"
  exit 1
fi
echo "OK"

echo -n "HEAD ${PATH_WS} (как curl -I — ожидаем 405)... "
head_code="$(curl --http1.1 -sS -o /dev/null -w '%{http_code}' -I \
  -H 'Upgrade: websocket' -H 'Connection: Upgrade' \
  -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  -H 'Sec-WebSocket-Protocol: binary' \
  "${BASE}${PATH_WS}")"
echo "HTTP ${head_code}"

echo -n "GET WebSocket upgrade (HTTP/1.1)... "
upgrade_headers="$(curl --http1.1 --max-time 15 -sS -D - -o /dev/null -X GET \
  -H 'Upgrade: websocket' -H 'Connection: Upgrade' \
  -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  -H 'Sec-WebSocket-Protocol: binary' \
  "${BASE}${PATH_WS}" 2>&1 | sed -n '1,15p' || true)"
status="$(echo "${upgrade_headers}" | head -1)"
proto="$(echo "${upgrade_headers}" | grep -i '^Sec-WebSocket-Protocol:' | tr -d '\r' || true)"
echo "${status}"
if ! echo "${status}" | grep -q '101'; then
  echo "FAIL: expected HTTP/1.1 101 Switching Protocols"
  echo "${upgrade_headers}"
  exit 1
fi
if [[ "${proto}" != *"binary"* ]]; then
  echo "WARN: missing Sec-WebSocket-Protocol: binary (${proto:-<none>})"
fi

echo -n "Python WebSocket ping... "
if WSS_URL="${WSS_URL}" python3 - <<'PY'
import asyncio
import os

async def main() -> None:
    import websockets

    url = os.environ["WSS_URL"]
    async with asyncio.timeout(20):
        async with websockets.connect(url, subprotocols=["binary"]) as ws:
            if ws.subprotocol != "binary":
                raise SystemExit(f"subprotocol={ws.subprotocol!r}, want binary")
            pong = await ws.ping()
            await asyncio.wait_for(pong, timeout=10)

asyncio.run(main())
PY
then
  echo "OK"
else
  echo "SKIP (pip install websockets)"
fi

echo ""
echo "✅ Public WSS path looks OK"
echo "   Браузер: DevTools → Network → WS → 101, URL ${WSS_URL}"
