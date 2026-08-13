#!/usr/bin/env bash
# Пути к runtime-библиотекам vcpkg (OpenSSL, zlib) для Windows-сборки TDLib.
set -euo pipefail

resolve_vcpkg_triplet() {
  echo "${VCPKG_DEFAULT_TRIPLET:-x64-windows}"
}

resolve_vcpkg_installed_dir() {
  local root_dir="${1:?}"

  if [[ -n "${VCPKG_INSTALLED_DIR:-}" ]]; then
    echo "${VCPKG_INSTALLED_DIR}"
    return 0
  fi

  if [[ -d "${root_dir}/vcpkg_installed" ]]; then
    echo "${root_dir}/vcpkg_installed"
    return 0
  fi

  if [[ -n "${VCPKG_ROOT:-}" && -d "${VCPKG_ROOT}/installed" ]]; then
    echo "${VCPKG_ROOT}/installed"
    return 0
  fi

  return 1
}

resolve_vcpkg_bin_dir() {
  local root_dir="${1:?}"
  local installed_dir triplet

  installed_dir="$(resolve_vcpkg_installed_dir "${root_dir}")"
  triplet="$(resolve_vcpkg_triplet)"
  echo "${installed_dir}/${triplet}/bin"
}
