#!/usr/bin/env bash
# Сборка tdweb (TDLib → WASM + webpack) для RioGram Web §8.2.
#
# Требования:
#   - emsdk 3.1.1 (source ~/emsdk/emsdk_env.sh)
#   - cmake, gperf, perl, php-cli, curl, tar, node/npm
#   - см. scripts/install-linux-build-deps.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TDWEB_DIR="${ROOT_DIR}/td/example/web"

if ! command -v emcc >/dev/null 2>&1; then
  if [[ -f "${HOME}/emsdk/emsdk_env.sh" ]]; then
    # shellcheck disable=SC1091
    source "${HOME}/emsdk/emsdk_env.sh"
  else
    echo "emcc не найден. Установите emsdk 3.1.1 и выполните:" >&2
    echo "  source ~/emsdk/emsdk_env.sh" >&2
    exit 1
  fi
fi

emcc --check 2>&1 | grep -q ' 3.1.1 ' || {
  echo "Требуется emcc 3.1.1 (см. td/example/web/README.md)" >&2
  exit 1
}

# generate-шаг TDLib использует системный cmake/c++ (не emscripten).
# В окружении с clang по умолчанию нужен g++ (ld: cannot find -lstdc++).
export CC="${CC:-gcc}"
export CXX="${CXX:-g++}"

cd "${TDWEB_DIR}"

echo "==> OpenSSL для Emscripten..."
./build-openssl.sh

echo "==> TDLib → WebAssembly..."
./build-tdlib.sh

echo "==> Копирование WASM в tdweb/src/prebuilt/release/..."
./copy-tdlib.sh

echo "==> Webpack: tdweb.js..."
./build-tdweb.sh

echo ""
echo "✅ tdweb собран: ${TDWEB_DIR}/tdweb/dist/"
echo "   Скопировать в web/: ./scripts/copy-tdweb.sh"
