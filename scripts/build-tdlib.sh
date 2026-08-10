#!/usr/bin/env bash
# Сборка модифицированного TDLib для RioGram (с DPI_BYPASS патчами).
#
# Переменные окружения:
#   TD_ENABLE_LTO   — ON/OFF (по умолчанию ON; в CI рекомендуется OFF)
#   CMAKE_BUILD_TYPE — Release/Debug (по умолчанию Release)
#   CC, CXX         — компилятор (в CI: gcc/g++ для ubuntu-latest)
#   JOBS            — параллельность сборки (по умолчанию nproc)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TD_DIR="${ROOT_DIR}/td"
BUILD_DIR="${TD_DIR}/build"
JOBS="${JOBS:-$(nproc)}"
TD_ENABLE_LTO="${TD_ENABLE_LTO:-ON}"
CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"

if [[ ! -d "${TD_DIR}" ]]; then
  echo "TDLib не найден. Клонируйте: git clone https://github.com/tdlib/td.git td"
  exit 1
fi

mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

cmake -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}" \
  -DTD_ENABLE_LTO="${TD_ENABLE_LTO}" \
  -DCMAKE_INSTALL_PREFIX="${BUILD_DIR}/install" \
  ..

cmake --build . --target install --parallel "${JOBS}"

echo ""
echo "✅ TDLib собран: ${BUILD_DIR}/install"
echo "Скопируйте libtdjson в runner вашей платформы (см. .cursor/commands/build-tdlib.md)"
