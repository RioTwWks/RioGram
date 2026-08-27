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

copy_tdweb_prebuilt_to_root() {
  local src_dir="$1"
  local dest_dir="$2"
  if [[ -d "${src_dir}/prebuilt" ]]; then
    mkdir -p "${dest_dir}/prebuilt"
    cp -a "${src_dir}/prebuilt/." "${dest_dir}/prebuilt/"
    echo "  + prebuilt/ → ${dest_dir}/prebuilt/ (worker dynamic imports)"
  fi
}

# worker-loader resolves *.worker.js / *.wasm / *.mem from site root, not /tdweb/.
WEB_ROOT="${ROOT_DIR}/web"
for pattern in '*.worker.js' '*.wasm' '*.mem'; do
  for f in "${DEST}"/${pattern}; do
    [[ -f "${f}" ]] || continue
    cp -f "${f}" "${WEB_ROOT}/"
    echo "  + web/$(basename "${f}") (tdweb chunk, site root)"
  done
done
copy_tdweb_prebuilt_to_root "${DEST}" "${WEB_ROOT}"

"${ROOT_DIR}/scripts/generate-wss-worker-config.sh"
"${ROOT_DIR}/scripts/patch-tdweb-worker-wss.sh" "${WEB_ROOT}"
"${ROOT_DIR}/scripts/patch-tdweb-close-timeout.sh" "${DEST}/tdweb.js"

echo "✅ Скопировано: ${DEST}/"
ls -lh "${DEST}/"
