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

# Match 3.1.1 in --version (emcc --check does not reliably print the version).
EMCC_VERSION_LINE="$(emcc --version 2>&1 | head -n 1 || true)"
if ! grep -qE '(^|[^0-9])3\.1\.1([^0-9]|$)' <<<"${EMCC_VERSION_LINE}"; then
  echo "Требуется emcc 3.1.1 (см. td/example/web/README.md)" >&2
  echo "Сейчас: ${EMCC_VERSION_LINE:-<empty>}" >&2
  echo "Проверьте: source ~/emsdk/emsdk_env.sh && emcc --version" >&2
  exit 1
fi
echo "==> emcc: ${EMCC_VERSION_LINE}"

# generate-шаг TDLib использует системный cmake/c++ (не emscripten).
# В окружении с clang по умолчанию нужен g++ (ld: cannot find -lstdc++).
export CC="${CC:-gcc}"
export CXX="${CXX:-g++}"

need_cmd() {
  local name="$1"
  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "${name} не найден в PATH." >&2
    echo "Установите зависимости: ./scripts/install-linux-build-deps.sh" >&2
    exit 1
  fi
  if ! "${name}" --version >/dev/null 2>&1 && ! "${name}" -version >/dev/null 2>&1; then
    local path
    path="$(command -v "${name}")"
    echo "${name} найден (${path}), но не запускается (Permission denied / битый бинарь)." >&2
    echo "Проверьте: ls -la \"${path}\"; type -a ${name}" >&2
    echo "Переустановите: sudo apt-get install --reinstall -y cmake gperf php-cli" >&2
    exit 1
  fi
}

need_cmd cmake
need_cmd gperf
need_cmd perl
need_cmd php
need_cmd npm
echo "==> cmake: $(command -v cmake) ($(cmake --version | head -n1))"

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
