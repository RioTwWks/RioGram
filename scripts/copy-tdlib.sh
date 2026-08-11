#!/usr/bin/env bash
# Копирует собранный libtdjson в каталоги Flutter-проекта перед сборкой.
# Использование: ./scripts/copy-tdlib.sh <linux|windows|macos|android>
set -euo pipefail

PLATFORM="${1:?Укажите платформу: linux|windows|macos|android}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${TD_INSTALL_DIR:-${ROOT_DIR}/td/build/install}"
# shellcheck source=lib/file-copy.sh
source "${ROOT_DIR}/scripts/lib/file-copy.sh"

copy_linux() {
  copy_into "${INSTALL_DIR}/lib/libtdjson.so" "${ROOT_DIR}/linux/runner/libtdjson.so"
}

copy_windows() {
  local dll="${INSTALL_DIR}/bin/tdjson.dll"
  if [[ ! -f "${dll}" ]]; then
    dll="${INSTALL_DIR}/lib/tdjson.dll"
  fi
  copy_into "${dll}" "${ROOT_DIR}/windows/runner/tdjson.dll"
}

copy_macos() {
  copy_into "${INSTALL_DIR}/lib/libtdjson.dylib" "${ROOT_DIR}/macos/Runner/libtdjson.dylib"
}

copy_android() {
  local libs_dir="${ROOT_DIR}/td/example/android/tdlib/libs"
  if [[ ! -d "${libs_dir}" ]]; then
    echo "Android TDLib не собран: ${libs_dir} не найден"
    exit 1
  fi

  for abi in arm64-v8a armeabi-v7a x86_64; do
    local lib="${libs_dir}/${abi}/libtdjson.so"
    if [[ -f "${lib}" ]]; then
      copy_into "${lib}" "${ROOT_DIR}/android/app/src/main/jniLibs/${abi}/libtdjson.so"
    fi
  done
}

case "${PLATFORM}" in
  linux) copy_linux ;;
  windows) copy_windows ;;
  macos) copy_macos ;;
  android) copy_android ;;
  *)
    echo "Неизвестная платформа: ${PLATFORM}"
    exit 1
    ;;
esac

echo "✅ libtdjson скопирован для ${PLATFORM}"
