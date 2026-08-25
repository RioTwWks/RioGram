#!/usr/bin/env bash
# Production-сборка RioGram Web (§8.5).
#
# Usage:
#   ./scripts/build-web.sh
#   WEB_BASE_HREF=/app/ ./scripts/build-web.sh
#   SKIP_TDWEB_CHECK=1 ./scripts/build-web.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Создан .env из .env.example"
fi

if [[ "${SKIP_TDWEB_CHECK:-0}" != "1" && ! -f web/tdweb/tdweb.js ]]; then
  echo "⚠  web/tdweb/tdweb.js не найден."
  echo "   TDLib в браузере не заработает без tdweb."
  echo "   Сборка: ./scripts/build-tdweb.sh && ./scripts/copy-tdweb.sh"
  echo "   Или: SKIP_TDWEB_CHECK=1 ./scripts/build-web.sh"
  exit 1
fi

flutter pub get

BUILD_ARGS=(build web --release --no-wasm-dry-run -t lib/main.dart)
if [[ -n "${WEB_BASE_HREF:-}" ]]; then
  BUILD_ARGS+=(--base-href "${WEB_BASE_HREF}")
fi

flutter "${BUILD_ARGS[@]}"

echo ""
echo "✅ Production Web собран: build/web/"
echo "   Локально:  cd build/web && python3 -m http.server 8765"
echo "   Деплой EU: ./scripts/deploy-web-eu.sh"
