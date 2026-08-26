#!/usr/bin/env bash
# Prepend WSS WebSocket hook loader into tdweb entry *.worker.js only.
#
# worker-loader spawns hash.worker.js; webpack chunks (1.hash.worker.js) are pulled
# via importScripts into the same global scope — patch only the entry worker.
#
# Usage:
#   ./scripts/patch-tdweb-worker-wss.sh
#   ./scripts/patch-tdweb-worker-wss.sh build/web
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${1:-${ROOT_DIR}/web}"
MARKER='/* riogram-wss-worker-hook */'
LOADER="${MARKER}
importScripts('/js/wss_proxy_worker_hook.js');
"

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "Directory not found: ${TARGET_DIR}" >&2
  exit 1
fi

if [[ ! -f "${ROOT_DIR}/web/js/wss_proxy_worker_hook.js" ]]; then
  echo "Missing web/js/wss_proxy_worker_hook.js" >&2
  exit 1
fi

is_entry_worker() {
  local base
  base="$(basename "$1")"
  [[ "${base}" =~ ^[0-9]+\..*\.worker\.js$ ]] && return 1
  return 0
}

patched=0
skipped=0
while IFS= read -r -d '' worker; do
  if ! is_entry_worker "${worker}"; then
    rel="${worker#${ROOT_DIR}/}"
    echo "  skip chunk ${rel}"
    skipped=$((skipped + 1))
    continue
  fi
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
  echo "No entry *.worker.js under ${TARGET_DIR} (run ./scripts/copy-tdweb.sh first)" >&2
  exit 1
fi

echo "✅ Patched ${patched} entry worker(s), skipped ${skipped} chunk(s)"
