#!/usr/bin/env bash
# Копирует libtdjson в готовый Flutter-бандл после flutter build.
# Использование: ./scripts/copy-tdlib-to-bundle.sh <linux|windows|macos>
set -euo pipefail

PLATFORM="${1:?Укажите платформу: linux|windows|macos}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${TD_INSTALL_DIR:-${ROOT_DIR}/td/build/install}"

case "${PLATFORM}" in
  linux)
    install -D "${INSTALL_DIR}/lib/libtdjson.so" \
      "${ROOT_DIR}/build/linux/x64/release/bundle/lib/libtdjson.so"
    ;;
  windows)
    local_dll="${INSTALL_DIR}/bin/tdjson.dll"
    if [[ ! -f "${local_dll}" ]]; then
      local_dll="${INSTALL_DIR}/lib/tdjson.dll"
    fi
    install -D "${local_dll}" \
      "${ROOT_DIR}/build/windows/x64/runner/Release/tdjson.dll"
    ;;
  macos)
    local app="${ROOT_DIR}/build/macos/Build/Products/Release/riogram.app"
    install -d "${app}/Contents/Frameworks"
    install -D "${INSTALL_DIR}/lib/libtdjson.dylib" \
      "${app}/Contents/Frameworks/libtdjson.dylib"
    ;;
  *)
    echo "Неизвестная платформа: ${PLATFORM}"
    exit 1
    ;;
esac

echo "✅ libtdjson добавлен в бандл ${PLATFORM}"
