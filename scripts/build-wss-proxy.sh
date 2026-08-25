#!/usr/bin/env bash
# Сборка riogram-wss-proxy (§8.3).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT_DIR}/server/wss-proxy"
OUT="${ROOT_DIR}/bin/riogram-wss-proxy"

mkdir -p "${ROOT_DIR}/bin"
cd "${SRC}"
go mod tidy
go build -trimpath -ldflags="-s -w" -o "${OUT}" .

echo "✅ ${OUT}"
