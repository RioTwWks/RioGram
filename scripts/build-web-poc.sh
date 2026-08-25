#!/usr/bin/env bash
# Сборка Web PoC §8.1 — UI без TDLib/Telegram.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Создан .env из .env.example"
fi

flutter pub get
flutter build web -t lib/main_web_poc.dart --release --no-wasm-dry-run

echo ""
echo "✅ Web PoC собран: build/web/"
echo "   Локальный просмотр: cd build/web && python3 -m http.server 8080"
