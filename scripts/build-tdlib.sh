#!/usr/bin/env bash
# Сборка модифицированного TDLib для RioGram (с DPI_BYPASS патчами).
#
# Переменные окружения:
#   TD_ENABLE_LTO    — ON/OFF (по умолчанию OFF; ON жрёт много RAM на этапе линковки ~90%)
#   CMAKE_BUILD_TYPE — Release/Debug (по умолчанию Release)
#   CC, CXX          — компилятор (рекомендуется gcc/g++ на Linux)
#   JOBS             — параллельность сборки (по умолчанию по доступной RAM, не nproc)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TD_DIR="${ROOT_DIR}/td"
BUILD_DIR="${TD_DIR}/build"

default_jobs() {
  if command -v nproc >/dev/null 2>&1; then
    nproc
  elif command -v sysctl >/dev/null 2>&1; then
    sysctl -n hw.ncpu
  else
    echo 4
  fi
}

available_memory_mb() {
  if [[ -r /proc/meminfo ]]; then
    local kb
    kb="$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo)"
    if [[ -z "${kb}" || "${kb}" == "0" ]]; then
      kb="$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo)"
    fi
    echo $((kb / 1024))
  elif command -v sysctl >/dev/null 2>&1; then
    echo $(($(sysctl -n hw.memsize) / 1024 / 1024))
  else
    echo 8192
  fi
}

memory_aware_jobs() {
  local nproc_jobs mem_mb jobs
  nproc_jobs="$(default_jobs)"
  mem_mb="$(available_memory_mb)"
  # ~1.8 GB на параллельный g++ job; ~2 GB резерв под ОС и линковку.
  jobs=$(( (mem_mb - 2048) / 1800 ))
  if (( jobs < 1 )); then
    jobs=1
  fi
  if (( jobs > nproc_jobs )); then
    jobs=$nproc_jobs
  fi
  echo "${jobs}"
}

JOBS="${JOBS:-$(memory_aware_jobs)}"
TD_ENABLE_LTO="${TD_ENABLE_LTO:-OFF}"
CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"
MEM_MB="$(available_memory_mb)"

if [[ ! -d "${TD_DIR}" ]]; then
  echo "TDLib не найден. Клонируйте: git clone https://github.com/tdlib/td.git td"
  exit 1
fi

if [[ "${TD_ENABLE_LTO}" == "ON" && "${MEM_MB}" -lt 16384 ]]; then
  echo "⚠️  TD_ENABLE_LTO=ON при ${MEM_MB} MB RAM может заморозить систему на этапе линковки (~90%)."
  echo "   Рекомендуется: TD_ENABLE_LTO=OFF JOBS=1 ./scripts/build-tdlib.sh"
  echo ""
fi

echo "Сборка TDLib: JOBS=${JOBS}, TD_ENABLE_LTO=${TD_ENABLE_LTO}, RAM≈${MEM_MB} MB, ${CMAKE_BUILD_TYPE}"
echo "При зависании ПК: JOBS=1 TD_ENABLE_LTO=OFF ./scripts/build-tdlib.sh"
echo ""

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
