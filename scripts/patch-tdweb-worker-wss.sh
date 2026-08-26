#!/usr/bin/env bash
# Prepend WSS WebSocket hook loader into tdweb *.worker.js (runs inside worker).
#
# worker-loader + webpack use relative importScripts — do NOT wrap Worker in blob: URLs.
# Hook logic lives in web/js/wss_proxy_worker_hook.js (same-origin fallback when .env empty).
#
# Usage:
#   ./scripts/patch-tdweb-worker-wss.sh
#   ./scripts/patch-tdweb-worker-wss.sh build/web
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${1:-${ROOT_DIR}/web}"
MARKER='/* riogram-wss-worker-hook */'
LOADER="${MARKER}
importScripts('js/wss_proxy_worker_hook.js');
"

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "Directory not found: ${TARGET_DIR}" >&2
  exit 1
fi

if [[ ! -f "${ROOT_DIR}/web/js/wss_proxy_worker_hook.js" ]]; then
  echo "Missing web/js/wss_proxy_worker_hook.js" >&2
  exit 1
fi

patched=0
while IFS= read -r -d '' worker; do
  python3 - "${worker}" "${MARKER}" "${LOADER}" <<'PY'
import re
import sys

path, marker, loader = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path, encoding="utf-8").read()
if marker in text:
    text = re.sub(
        re.escape(marker) + r".*?(?:\n|$)",
        "",
        text,
        count=1,
    )
    # Remove legacy inline hook block (previous patch format).
    text = re.sub(
        re.escape(marker) + r".*?\}\)\(\);\n?",
        "",
        text,
        count=1,
        flags=re.DOTALL,
    )
open(path, "w", encoding="utf-8").write(loader + "\n" + text.lstrip("\n"))
PY
  rel="${worker#${ROOT_DIR}/}"
  echo "  patched ${rel}"
  patched=$((patched + 1))
done < <(find "${TARGET_DIR}" -maxdepth 2 -name '*.worker.js' -print0)

if [[ "${patched}" -eq 0 ]]; then
  echo "No *.worker.js under ${TARGET_DIR} (run ./scripts/copy-tdweb.sh first)"
else
  echo "✅ Patched ${patched} worker file(s) → importScripts(js/wss_proxy_worker_hook.js)"
fi
