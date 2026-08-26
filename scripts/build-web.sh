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

if [[ -z "${TELEGRAM_API_ID:-}" || -z "${TELEGRAM_API_HASH:-}" ]]; then
  # shellcheck disable=SC1091
  set -a
  source .env 2>/dev/null || true
  set +a
fi

API_ID="${TELEGRAM_API_ID:-}"
if [[ -z "${API_ID}" || "${API_ID}" == "0" ]]; then
  echo "❌ TELEGRAM_API_ID не задан в .env"
  echo "   export TELEGRAM_API_ID=... TELEGRAM_API_HASH=... && ./scripts/generate-env.sh"
  echo "   или заполните .env вручную (см. docs/SECRETS.md)"
  exit 1
fi
if [[ -z "${TELEGRAM_API_HASH:-}" ]]; then
  echo "❌ TELEGRAM_API_HASH не задан в .env"
  exit 1
fi

"${ROOT_DIR}/scripts/generate-wss-worker-config.sh"

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

# worker-loader resolves *.worker.js / *.wasm / *.mem from site root.
BUILD_WEB="${ROOT_DIR}/build/web"
if [[ -d "${BUILD_WEB}/tdweb" ]]; then
  for pattern in '*.worker.js' '*.wasm' '*.mem'; do
    for f in "${BUILD_WEB}/tdweb"/${pattern}; do
      [[ -f "${f}" ]] || continue
      cp -f "${f}" "${BUILD_WEB}/"
    done
  done
fi

if compgen -G "${BUILD_WEB}/*.worker.js" >/dev/null || compgen -G "${BUILD_WEB}/tdweb/*.worker.js" >/dev/null; then
  "${ROOT_DIR}/scripts/patch-tdweb-worker-wss.sh" "${BUILD_WEB}"
else
  echo "⚠  tdweb workers not found — WSS worker patch skipped (OK for SKIP_TDWEB_CHECK builds)"
fi

echo ""
echo "✅ Production Web собран: build/web/"
echo "   Локально:  cd build/web && python3 -m http.server 8765"
echo "   Деплой EU: ./scripts/deploy-web-eu.sh"
