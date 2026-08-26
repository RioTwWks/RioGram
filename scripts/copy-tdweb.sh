#!/usr/bin/env bash
# Копирует собранный tdweb в web/tdweb/ для Flutter build web.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT_DIR}/td/example/web/tdweb/dist"
DEST="${ROOT_DIR}/web/tdweb"

if [[ ! -f "${SRC}/tdweb.js" ]]; then
  echo "tdweb.js не найден. Сначала выполните: ./scripts/build-tdweb.sh" >&2
  exit 1
fi

mkdir -p "${DEST}"
rm -rf "${DEST:?}/"*
cp -a "${SRC}/." "${DEST}/"

# worker-loader resolves *.worker.js / *.wasm / *.mem from site root, not /tdweb/.
WEB_ROOT="${ROOT_DIR}/web"
for pattern in '*.worker.js' '*.wasm' '*.mem'; do
  for f in "${DEST}"/${pattern}; do
    [[ -f "${f}" ]] || continue
    cp -f "${f}" "${WEB_ROOT}/"
    echo "  + web/$(basename "${f}") (tdweb chunk, site root)"
  done
done

echo "✅ Скопировано: ${DEST}/"
ls -lh "${DEST}/"
