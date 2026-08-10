#!/usr/bin/env bash
# Локальный запуск проверок Flutter, как в GitHub Actions (job flutter).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Создан .env из .env.example"
fi

flutter pub get
flutter analyze --no-fatal-infos
flutter test

echo ""
echo "✅ Flutter CI-проверки пройдены"
