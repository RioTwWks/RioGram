#!/usr/bin/env bash
# Prepend WSS WebSocket hook into tdweb *.worker.js (runs inside worker, not main page).
#
# worker-loader + webpack use relative importScripts — do NOT wrap Worker in blob: URLs.
# Reads WEB_WSS_PROXY_URL from .env (enabled=true when set).
#
# Usage:
#   ./scripts/patch-tdweb-worker-wss.sh
#   ./scripts/patch-tdweb-worker-wss.sh build/web
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${1:-${ROOT_DIR}/web}"
MARKER='/* riogram-wss-worker-hook */'

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "Directory not found: ${TARGET_DIR}" >&2
  exit 1
fi

ENV_FILE="${ROOT_DIR}/.env"
WSS_URL=""
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "${ENV_FILE}"
  set +a
fi
WSS_URL="${WEB_WSS_PROXY_URL:-}"

ENABLED="false"
if [[ -n "${WSS_URL}" ]]; then
  ENABLED="true"
fi

WSS_JSON=$(WSS_URL="${WSS_URL}" ENABLED="${ENABLED}" python3 <<'PY'
import json, os
print(json.dumps({
    "enabled": os.environ.get("ENABLED") == "true",
    "url": os.environ.get("WSS_URL", ""),
}))
PY
)

patched=0
while IFS= read -r -d '' worker; do
  python3 - "${worker}" "${MARKER}" "${WSS_JSON}" <<'PY'
import re
import sys

path, marker, config_json = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path, encoding="utf-8").read()
if marker in text:
    text = re.sub(
        re.escape(marker) + r".*?\}\)\(\);\n?",
        "",
        text,
        count=1,
        flags=re.DOTALL,
    )
hook = f"""{marker}
(function () {{
  'use strict';
  var CONFIG = {config_json};
  var TELEGRAM_WS_RE = /^wss:\\/\\/([a-z0-9.-]+\\.(?:web\\.)?telegram\\.org)(\\/.*)?$/i;
  function normalizeProxyBase(raw) {{
    if (!raw || !String(raw).trim()) return null;
    var value = String(raw).trim();
    if (value.indexOf('https://') === 0) value = 'wss://' + value.slice(8);
    else if (value.indexOf('http://') === 0) value = 'ws://' + value.slice(7);
    else if (value.indexOf('wss://') !== 0 && value.indexOf('ws://') !== 0) value = 'wss://' + value;
    while (value.charAt(value.length - 1) === '/') value = value.slice(0, -1);
    return value;
  }}
  function rewriteUrl(url) {{
    if (!CONFIG.enabled || !CONFIG.url) return url;
    var proxyBase = normalizeProxyBase(CONFIG.url);
    if (!proxyBase) return url;
    var match = String(url).match(TELEGRAM_WS_RE);
    if (!match) return url;
    return proxyBase + '/' + match[1] + (match[2] || '/apiws');
  }}
  var OriginalWebSocket = self.WebSocket;
  function PatchedWebSocket(url, protocols) {{
    var targetUrl = rewriteUrl(url);
    return protocols === undefined
      ? new OriginalWebSocket(targetUrl)
      : new OriginalWebSocket(targetUrl, protocols);
  }}
  PatchedWebSocket.prototype = OriginalWebSocket.prototype;
  PatchedWebSocket.CONNECTING = OriginalWebSocket.CONNECTING;
  PatchedWebSocket.OPEN = OriginalWebSocket.OPEN;
  PatchedWebSocket.CLOSING = OriginalWebSocket.CLOSING;
  PatchedWebSocket.CLOSED = OriginalWebSocket.CLOSED;
  self.WebSocket = PatchedWebSocket;
}})();
"""
open(path, "w", encoding="utf-8").write(hook + "\n" + text.lstrip("\n"))
PY
  rel="${worker#${ROOT_DIR}/}"
  echo "  patched ${rel}"
  patched=$((patched + 1))
done < <(find "${TARGET_DIR}" -maxdepth 2 -name '*.worker.js' -print0)

if [[ "${patched}" -eq 0 ]]; then
  echo "No *.worker.js under ${TARGET_DIR} (run ./scripts/copy-tdweb.sh first)"
else
  echo "✅ Patched ${patched} worker file(s) (WSS enabled=${ENABLED}, url=${WSS_URL:-<empty>})"
fi
