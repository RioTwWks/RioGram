#!/usr/bin/env bash
# WSS stability test through local/production proxy path (§8.6).
#
# Usage:
#   ./scripts/e2e-wss-stability.sh
#   WSS_URL=ws://127.0.0.1:8080/venus.web.telegram.org/apiws WSS_STABILITY_SECONDS=65 ./scripts/e2e-wss-stability.sh
set -euo pipefail

WSS_URL="${WSS_URL:-ws://127.0.0.1:8080/venus.web.telegram.org/apiws}"
WSS_STABILITY_SECONDS="${WSS_STABILITY_SECONDS:-65}"

export WSS_URL WSS_STABILITY_SECONDS
python3 - <<'PY'
import asyncio
import os
import sys
import time

try:
    import websockets
except ImportError:
    print("Install: pip install websockets", file=sys.stderr)
    sys.exit(1)

url = os.environ["WSS_URL"]
duration = int(os.environ.get("WSS_STABILITY_SECONDS", "65"))
interval = 10

async def main() -> None:
    start = time.monotonic()
    pings = 0
    print(f"WSS stability: {url} for {duration}s")
    async with websockets.connect(url, subprotocols=["binary"], ping_interval=None) as ws:
        while time.monotonic() - start < duration:
            waiter = await ws.ping()
            await asyncio.wait_for(waiter, timeout=15)
            pings += 1
            elapsed = int(time.monotonic() - start)
            print(f"  ping {pings} OK ({elapsed}s)")
            remaining = duration - elapsed
            if remaining <= 0:
                break
            await asyncio.sleep(min(interval, remaining))
    print(f"OK: {pings} pings over {duration}s")

asyncio.run(main())
PY

echo "✅ WSS stable for ${WSS_STABILITY_SECONDS}s"
