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

validate_ee_secret() {
  local name="$1"
  local secret="${2:-}"
  if [[ -z "${secret}" ]]; then
    return 0
  fi
  if [[ ! "${secret}" =~ ^[0-9a-fA-F]+$ ]]; then
    echo "Ошибка: ${name} должен быть hex (ee + 32 символа ключа + домен в hex)."
    exit 1
  fi
  if [[ "${#secret}" -lt 34 ]]; then
    echo "Ошибка: ${name} слишком короткий (${#secret} hex-символов)."
    echo "Нужен ee + 16 байт ключа + домен, например: ee40197a...67626f6c2e636f6d"
    exit 1
  fi
  if [[ ! "${secret}" =~ ^ee ]]; then
    echo "Предупреждение: ${name} не начинается с ee (Fake TLS)."
  fi
}

if [[ "${REQUIRE_SECRETS:-}" == "true" ]]; then
  if [[ -z "${TELEGRAM_API_ID:-}" || -z "${TELEGRAM_API_HASH:-}" ]]; then
    echo "Ошибка: TELEGRAM_API_ID и TELEGRAM_API_HASH обязательны для этой сборки."
    echo "Добавьте secrets в GitHub: Settings → Secrets and variables → Actions"
    echo "См. docs/SECRETS.md"
    exit 1
  fi
  validate_ee_secret "PROXY_PHANTOM_SECRET" "${PROXY_PHANTOM_SECRET:-}"
  validate_ee_secret "PROXY_STEALTH_SECRET" "${PROXY_STEALTH_SECRET:-}"
fi

cat > "${ENV_FILE}" <<EOF
# Сгенерировано scripts/generate-env.sh — не коммитить
TELEGRAM_API_ID=${TELEGRAM_API_ID:-}
TELEGRAM_API_HASH=${TELEGRAM_API_HASH:-}

PROXY_PHANTOM_HOST=${PROXY_PHANTOM_HOST:-}
PROXY_PHANTOM_PORT=${PROXY_PHANTOM_PORT:-15443}
PROXY_PHANTOM_SECRET=${PROXY_PHANTOM_SECRET:-}

PROXY_STEALTH_HOST=${PROXY_STEALTH_HOST:-}
PROXY_STEALTH_PORT=${PROXY_STEALTH_PORT:-14443}
PROXY_STEALTH_SECRET=${PROXY_STEALTH_SECRET:-}
EOF

echo "✅ .env создан из переменных окружения"
