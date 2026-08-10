#!/usr/bin/env bash
# Сборка libtdjson.a для iOS (устройство) и копирование в ios/Frameworks/.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TD_DIR="${ROOT_DIR}/td"
IOS_EXAMPLE="${TD_DIR}/example/ios"
FRAMEWORKS_DIR="${ROOT_DIR}/ios/Frameworks"
BUILD_DIR="${TD_DIR}/build-ios-device"
INSTALL_DIR="${TD_DIR}/build-ios-install"
OPENSSL_IOS="${IOS_EXAMPLE}/third_party/openssl/iOS"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew не найден — требуется macOS runner"
  exit 1
fi

brew list gperf >/dev/null 2>&1 || brew install gperf
brew list cmake >/dev/null 2>&1 || brew install cmake
brew list coreutils >/dev/null 2>&1 || brew install coreutils

mkdir -p "${FRAMEWORKS_DIR}"

# Генерация исходников TDLib (нативная сборка на macOS)
if [[ ! -f "${TD_DIR}/td/generate/auto/td/telegram/td_api.h" ]]; then
  mkdir -p "${TD_DIR}/build-native"
  cmake -S "${TD_DIR}" -B "${TD_DIR}/build-native" -DTD_GENERATE_SOURCE_FILES=ON
  cmake --build "${TD_DIR}/build-native"
fi

cd "${IOS_EXAMPLE}"

if [[ ! -d "${OPENSSL_IOS}" ]]; then
  echo "Сборка OpenSSL для iOS (может занять 10–20 мин)..."
  ./build-openssl.sh
fi

if [[ ! -f "${FRAMEWORKS_DIR}/libtdjson.a" ]]; then
  echo "Сборка TDLib static для iOS..."
  rm -rf "${BUILD_DIR}" "${INSTALL_DIR}"
  mkdir -p "${BUILD_DIR}" "${INSTALL_DIR}"

  openssl_path="$(grealpath "${OPENSSL_IOS}")"
  openssl_crypto="${openssl_path}/lib/libcrypto.a"
  openssl_ssl="${openssl_path}/lib/libssl.a"

  cmake -S "${TD_DIR}" -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DTD_ENABLE_LTO=OFF \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -DIOS_PLATFORM=OS \
    -DCMAKE_TOOLCHAIN_FILE="${TD_DIR}/CMake/iOS.cmake" \
    -DOPENSSL_FOUND=1 \
    -DOPENSSL_CRYPTO_LIBRARY="${openssl_crypto}" \
    -DOPENSSL_SSL_LIBRARY="${openssl_ssl}" \
    -DOPENSSL_INCLUDE_DIR="${openssl_path}/include" \
    -DOPENSSL_LIBRARIES="${openssl_crypto};${openssl_ssl}"

  cmake --build "${BUILD_DIR}" --target tdjson_static --parallel "$(sysctl -n hw.ncpu)"
  cp "${BUILD_DIR}/libtdjson_static.a" "${FRAMEWORKS_DIR}/libtdjson.a"
fi

echo "✅ libtdjson.a → ${FRAMEWORKS_DIR}/libtdjson.a"
