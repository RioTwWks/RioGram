#!/usr/bin/env bash
# Сборка TDLib для macOS (Homebrew OpenSSL).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew не найден — требуется macOS runner"
  exit 1
fi

brew list gperf >/dev/null 2>&1 || brew install gperf
brew list openssl@3 >/dev/null 2>&1 || brew install openssl@3
brew list cmake >/dev/null 2>&1 || brew install cmake

export OPENSSL_ROOT_DIR="$(brew --prefix openssl@3)"
export CC=clang
export CXX=clang++
export TD_ENABLE_LTO=OFF

"${ROOT_DIR}/scripts/build-tdlib.sh"
