#!/usr/bin/env bash
# Копирует libtdjson в готовый Flutter-бандл после flutter build.
# Использование: ./scripts/copy-tdlib-to-bundle.sh <linux|windows|macos>
set -euo pipefail

PLATFORM="${1:?Укажите платформу: linux|windows|macos}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${TD_INSTALL_DIR:-${ROOT_DIR}/td/build/install}"
# shellcheck source=lib/file-copy.sh
source "${ROOT_DIR}/scripts/lib/file-copy.sh"
# shellcheck source=lib/vcpkg-runtime.sh
source "${ROOT_DIR}/scripts/lib/vcpkg-runtime.sh"

copy_windows_vcpkg_runtime_dlls() {
  local dest_dir="${1:?}"
  local vcpkg_bin

  if ! vcpkg_bin="$(resolve_vcpkg_bin_dir "${ROOT_DIR}")"; then
    echo "copy-tdlib-to-bundle.sh: vcpkg bin не найден — пропуск runtime DLL"
    return 0
  fi

  if [[ ! -d "${vcpkg_bin}" ]]; then
    echo "copy-tdlib-to-bundle.sh: каталог vcpkg bin отсутствует: ${vcpkg_bin}"
    return 0
  fi

  local copied=0
  shopt -s nullglob
  for dll in \
    "${vcpkg_bin}"/libcrypto*.dll \
    "${vcpkg_bin}"/libssl*.dll \
    "${vcpkg_bin}"/zlib*.dll \
    "${vcpkg_bin}"/z.dll; do
    copy_into "${dll}" "${dest_dir}/$(basename "${dll}")"
    copied=$((copied + 1))
  done
  shopt -u nullglob

  if [[ "${copied}" -eq 0 ]]; then
    echo "copy-tdlib-to-bundle.sh: предупреждение — в ${vcpkg_bin} нет OpenSSL/zlib DLL"
  fi
}

case "${PLATFORM}" in
  linux)
    copy_into "${INSTALL_DIR}/lib/libtdjson.so" \
      "${ROOT_DIR}/build/linux/x64/release/bundle/lib/libtdjson.so"
    ;;
  windows)
    dll_path="${INSTALL_DIR}/bin/tdjson.dll"
    if [[ ! -f "${dll_path}" ]]; then
      dll_path="${INSTALL_DIR}/lib/tdjson.dll"
    fi
    dest_dir="${ROOT_DIR}/build/windows/x64/runner/Release"
    copy_into "${dll_path}" "${dest_dir}/tdjson.dll"
    copy_windows_vcpkg_runtime_dlls "${dest_dir}"
    ;;
  macos)
    app_path="${ROOT_DIR}/build/macos/Build/Products/Release/riogram.app"
    mkdir -p "${app_path}/Contents/Frameworks"
    copy_into "${INSTALL_DIR}/lib/libtdjson.dylib" \
      "${app_path}/Contents/Frameworks/libtdjson.dylib"
    ;;
  *)
    echo "Неизвестная платформа: ${PLATFORM}"
    exit 1
    ;;
esac

echo "✅ libtdjson добавлен в бандл ${PLATFORM}"
