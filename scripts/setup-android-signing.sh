#!/usr/bin/env bash
# Подготовка release-подписи Android из переменных окружения (CI / локально).
#
# Переменные:
#   ANDROID_KEYSTORE_BASE64   — keystore (.jks) в base64
#   ANDROID_KEYSTORE_PASSWORD — пароль хранилища
#   ANDROID_KEY_PASSWORD      — пароль ключа (если отличается от store)
#   ANDROID_KEY_ALIAS         — alias ключа (например riogram)
#
# Без ANDROID_KEYSTORE_BASE64 скрипт завершается успешно — Gradle использует debug-подпись.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEYSTORE_PATH="${ROOT_DIR}/android/app/riogram-release.jks"
KEY_PROPERTIES="${ROOT_DIR}/android/key.properties"

if [[ -z "${ANDROID_KEYSTORE_BASE64:-}" ]]; then
  echo "ℹ️  ANDROID_KEYSTORE_BASE64 не задан — release-сборка будет с debug-подписью"
  exit 0
fi

: "${ANDROID_KEYSTORE_PASSWORD:?Задайте ANDROID_KEYSTORE_PASSWORD}"
: "${ANDROID_KEY_ALIAS:?Задайте ANDROID_KEY_ALIAS}"

KEY_PASSWORD="${ANDROID_KEY_PASSWORD:-${ANDROID_KEYSTORE_PASSWORD}}"

echo "${ANDROID_KEYSTORE_BASE64}" | base64 --decode > "${KEYSTORE_PATH}"

cat > "${KEY_PROPERTIES}" <<EOF
storePassword=${ANDROID_KEYSTORE_PASSWORD}
keyPassword=${KEY_PASSWORD}
keyAlias=${ANDROID_KEY_ALIAS}
storeFile=${KEYSTORE_PATH}
EOF

echo "✅ Android signing: key.properties и keystore подготовлены"
