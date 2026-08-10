#!/usr/bin/env bash
# Сборка TDLib для Android (JSON interface) через официальные скрипты TDLib.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_EXAMPLE="${ROOT_DIR}/td/example/android"
OPENSSL_DIR="${ROOT_DIR}/.cache/openssl-android"
TDLIB_CACHE="${ANDROID_EXAMPLE}/tdlib"

if [[ -z "${ANDROID_HOME:-}" && -z "${ANDROID_SDK_ROOT:-}" ]]; then
  echo "ANDROID_HOME / ANDROID_SDK_ROOT не задан"
  exit 1
fi

export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT}}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME}}"

cd "${ANDROID_EXAMPLE}"
./check-environment.sh

NDK_VERSION="${ANDROID_NDK_VERSION:-}"
if [[ -z "${NDK_VERSION}" ]]; then
  NDK_VERSION="$(ls -1 "${ANDROID_HOME}/ndk" 2>/dev/null | sort -V | tail -1)"
fi
if [[ -z "${NDK_VERSION}" ]]; then
  echo "Android NDK не найден в ${ANDROID_HOME}/ndk"
  exit 1
fi

echo "Android SDK: ${ANDROID_HOME}"
echo "Android NDK: ${NDK_VERSION}"

if [[ ! -d "${OPENSSL_DIR}" ]]; then
  echo "Сборка OpenSSL для Android..."
  ./build-openssl.sh "${ANDROID_HOME}" "${NDK_VERSION}" "${OPENSSL_DIR}"
fi

if [[ ! -f "${TDLIB_CACHE}/libs/arm64-v8a/libtdjson.so" ]]; then
  echo "Сборка TDLib для Android (JSON)..."
  ./build-tdlib.sh "${ANDROID_HOME}" "${NDK_VERSION}" "${OPENSSL_DIR}" "c++_static" "JSON"
fi

"${ROOT_DIR}/scripts/copy-tdlib.sh" android
