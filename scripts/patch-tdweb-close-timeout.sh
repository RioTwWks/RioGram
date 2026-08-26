#!/usr/bin/env bash
# Patches built tdweb.js: 5s timeout on closeOtherClients waitSet (prevents infinite hang).
#
# Usage:
#   ./scripts/patch-tdweb-close-timeout.sh
#   ./scripts/patch-tdweb-close-timeout.sh build/web/tdweb/tdweb.js
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKER='/* riogram-closeOtherClients-timeout */'

patch_file() {
  local target="$1"
  [[ -f "${target}" ]] || return 0
  if grep -q "${MARKER}" "${target}" 2>/dev/null; then
    echo "  already patched: ${target}"
    return 0
  fi

  python3 - "${target}" "${MARKER}" <<'PY'
import re
import sys

path, marker = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()

old = """if (this.waitSet.size !== 0) {
      await new Promise(resolve => {
        this.onWaitSetEmpty = resolve;
      });
    }"""

new = marker + """
if (this.waitSet.size !== 0) {
      await Promise.race([
        new Promise(resolve => {
          this.onWaitSetEmpty = resolve;
        }),
        sleep(5000).then(() => {
          log.warn(
            'closeOtherClients: waitSet not empty after 5s, proceeding anyway',
            this.waitSet
          );
        })
      ]);
    }"""

if old not in text:
    # Minified / webpack variants
    pattern = re.compile(
        r"if\s*\(\s*this\.waitSet\.size\s*!==\s*0\s*\)\s*\{\s*"
        r"await\s+new\s+Promise\s*\(\s*resolve\s*=>\s*\{\s*"
        r"this\.onWaitSetEmpty\s*=\s*resolve;\s*\}\s*\);\s*\}",
        re.MULTILINE,
    )
    if not pattern.search(text):
        print(f"⚠  closeOtherClients pattern not found in {path}", file=sys.stderr)
        sys.exit(0)
    text = pattern.sub(
        marker
        + """
if (this.waitSet.size !== 0) {
      await Promise.race([
        new Promise(resolve => {
          this.onWaitSetEmpty = resolve;
        }),
        sleep(5000).then(() => {
          log.warn('closeOtherClients: waitSet timeout, proceeding anyway', this.waitSet);
        })
      ]);
    }""",
        text,
        count=1,
    )
else:
    text = text.replace(old, new, 1)

open(path, "w", encoding="utf-8").write(text)
print(f"  patched {path}")
PY
}

targets=()
if [[ $# -gt 0 ]]; then
  targets=("$@")
else
  for candidate in \
    "${ROOT_DIR}/web/tdweb/tdweb.js" \
    "${ROOT_DIR}/build/web/tdweb/tdweb.js"; do
    [[ -f "${candidate}" ]] && targets+=("${candidate}")
  done
fi

if [[ ${#targets[@]} -eq 0 ]]; then
  echo "⚠  No tdweb.js found — closeOtherClients patch skipped"
  exit 0
fi

for f in "${targets[@]}"; do
  patch_file "${f}"
done

echo "✅ closeOtherClients timeout patch done"
