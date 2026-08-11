#!/usr/bin/env bash
# Создаёт .env из переменных окружения.
#
# Локально:
#   export TELEGRAM_API_ID=... TELEGRAM_API_HASH=...
#   ./scripts/generate-env.sh
#
# GitHub Actions: значения передаются из Repository Secrets (см. docs/SECRETS.md).
#
# Переменные:
#   REQUIRE_SECRETS=true — завершить с ошибкой, если нет TELEGRAM_API_ID/HASH
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ "${REQUIRE_SECRETS:-}" == "true" ]]; then
  if [[ -z "${TELEGRAM_API_ID:-}" || -z "${TELEGRAM_API_HASH:-}" ]]; then
    echo "Ошибка: TELEGRAM_API_ID и TELEGRAM_API_HASH обязательны для этой сборки."
    echo "Добавьте secrets в GitHub: Settings → Secrets and variables → Actions"
    echo "См. docs/SECRETS.md"
    exit 1
  fi
fi

cat > "${ENV_FILE}" <<EOF
# Сгенерировано scripts/generate-env.sh — не коммитить
TELEGRAM_API_ID=${TELEGRAM_API_ID:-}
TELEGRAM_API_HASH=${TELEGRAM_API_HASH:-}

PROXY_PHANTOM_HOST=${PROXY_PHANTOM_HOST:-}
PROXY_PHANTOM_PORT=${PROXY_PHANTOM_PORT:-443}
PROXY_PHANTOM_SECRET=${PROXY_PHANTOM_SECRET:-}

PROXY_STEALTH_HOST=${PROXY_STEALTH_HOST:-}
PROXY_STEALTH_PORT=${PROXY_STEALTH_PORT:-443}
PROXY_STEALTH_SECRET=${PROXY_STEALTH_SECRET:-}
EOF

echo "✅ .env создан из переменных окружения"
