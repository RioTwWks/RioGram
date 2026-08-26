#!/usr/bin/env bash
# Inline WSS WebSocket hook into all tdweb *.worker.js files.
#
# Embeds WEB_WSS_PROXY_URL from .env directly into the worker — no importScripts.
# Chunk workers (1.<hash>.worker.js) need the hook when used as pthread entry points.
# importScripts into the main tdweb worker is safe: __RIOGRAM_WSS_HOOK__ guard skips re-install.
#
# Usage:
#   ./scripts/patch-tdweb-worker-wss.sh
#   ./scripts/patch-tdweb-worker-wss.sh build/web
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${1:-${ROOT_DIR}/web}"
MARKER='/* riogram-wss-worker-hook */'
HOOK_TEMPLATE="${ROOT_DIR}/web/js/wss_proxy_worker_hook.js"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "Directory not found: ${TARGET_DIR}" >&2
  exit 1
fi

if [[ ! -f "${HOOK_TEMPLATE}" ]]; then
  echo "Missing ${HOOK_TEMPLATE}" >&2
  exit 1
fi

WSS_URL=""
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "${ENV_FILE}"
  set +a
fi
WSS_URL="${WEB_WSS_PROXY_URL:-}"

INLINE_HOOK="$(python3 - "${HOOK_TEMPLATE}" "${WSS_URL}" <<'PY'
import json
import sys

template_path, wss_url = sys.argv[1], sys.argv[2]
template = open(template_path, encoding="utf-8").read()
baked = json.dumps(wss_url)[1:-1]  # JS string literal contents
inline = template.replace("__RIOGRAM_BAKED_PROXY_URL__", baked)
print(inline.rstrip())
PY
)"

strip_hook() {
  python3 - "$1" "${MARKER}" <<'PY'
import re
import sys

path, marker = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
if marker not in text:
    sys.exit(0)
text = re.sub(re.escape(marker) + r".*?\}\)\(\);\n?", "", text, count=1, flags=re.DOTALL)
text = re.sub(re.escape(marker) + r".*?(?:\n|$)", "", text, count=1)
open(path, "w", encoding="utf-8").write(text.lstrip("\n"))
PY
}

patched=0
while IFS= read -r -d '' worker; do
  strip_hook "${worker}"
  python3 - "${worker}" "${MARKER}" "${INLINE_HOOK}" <<'PY'
import sys

path, marker, hook = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(marker + "\n" + hook + "\n" + text.lstrip("\n"))
PY
  rel="${worker#${ROOT_DIR}/}"
  echo "  patched ${rel}"
  patched=$((patched + 1))
done < <(find "${TARGET_DIR}" -maxdepth 2 -name '*.worker.js' -print0)

if [[ "${patched}" -eq 0 ]]; then
  echo "⚠  No *.worker.js under ${TARGET_DIR} — skipped WSS worker patch"
  exit 0
fi

echo "✅ Patched ${patched} worker(s) (baked proxy=${WSS_URL:-<same-origin>})"
