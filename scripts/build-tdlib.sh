#!/usr/bin/env bash
# Сборка модифицированного TDLib для RioGram (с DPI_BYPASS патчами).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TD_DIR="${ROOT_DIR}/td"
BUILD_DIR="${TD_DIR}/build"
JOBS="${JOBS:-$(nproc)}"

if [[ ! -d "${TD_DIR}" ]]; then
  echo "TDLib не найден. Клонируйте: git clone https://github.com/tdlib/td.git td"
  exit 1
fi

mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

cmake -DCMAKE_BUILD_TYPE=Release \
  -DTD_ENABLE_LTO=ON \
  -DCMAKE_INSTALL_PREFIX="${BUILD_DIR}/install" \
  ..

cmake --build . --target install --parallel "${JOBS}"

echo ""
echo "✅ TDLib собран: ${BUILD_DIR}/install"
echo "Скопируйте libtdjson в runner вашей платформы (см. .cursor/commands/build-tdlib.md)"
