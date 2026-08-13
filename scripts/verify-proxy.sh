#!/usr/bin/env bash
# Проверка доступности PhantomProxy / StealthGate до запуска RioGram.
#
# Использование:
#   ./scripts/verify-proxy.sh
#   PROXY_PHANTOM_HOST=1.2.3.4 PROXY_PHANTOM_PORT=15443 ./scripts/verify-proxy.sh
#
# Читает .env в корне репозитория или переменные окружения.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "${ENV_FILE}"
  set +a
fi

check_tcp() {
  local name="$1"
  local host="$2"
  local port="$3"
  if [[ -z "${host}" ]]; then
    echo "⏭  ${name}: хост не задан"
    return 0
  fi
  echo -n "TCP ${name} (${host}:${port})... "
  if timeout 5 bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
    echo "OK"
    return 0
  fi
  echo "FAIL"
  return 1
}

check_tls() {
  local name="$1"
  local host="$2"
  local port="$3"
  local secret="$4"
  if [[ -z "${host}" || -z "${secret}" ]]; then
    return 0
  fi

  # Извлекаем SNI-домен из ee-секрета (байты после 17-го).
  local domain_hex="${secret:34}"
  local sni=""
  if [[ -n "${domain_hex}" && "${domain_hex}" =~ ^[0-9a-fA-F]+$ ]]; then
    sni=$(printf '%s' "${domain_hex}" | xxd -r -p 2>/dev/null || true)
  fi
  if [[ -z "${sni}" ]]; then
    sni="www.google.com"
    echo "⚠  ${name}: домен в secret не распознан, используем SNI=${sni}"
  fi

  echo -n "TLS ${name} (SNI=${sni})... "
  if timeout 8 openssl s_client -connect "${host}:${port}" -servername "${sni}" -brief </dev/null 2>/dev/null | grep -q "CONNECTION ESTABLISHED"; then
    echo "OK (TCP+TLS handshake)"
    return 0
  fi
  echo "нет ответа (возможен reject ECH/secret — см. логи прокси)"
  return 1
}

failed=0
check_tcp "PhantomProxy" "${PROXY_PHANTOM_HOST:-}" "${PROXY_PHANTOM_PORT:-15443}" || failed=1
check_tls "PhantomProxy" "${PROXY_PHANTOM_HOST:-}" "${PROXY_PHANTOM_PORT:-15443}" "${PROXY_PHANTOM_SECRET:-}" || failed=1
check_tcp "StealthGate" "${PROXY_STEALTH_HOST:-}" "${PROXY_STEALTH_PORT:-14443}" || failed=1
check_tls "StealthGate" "${PROXY_STEALTH_HOST:-}" "${PROXY_STEALTH_PORT:-14443}" "${PROXY_STEALTH_SECRET:-}" || failed=1

if [[ "${failed}" -ne 0 ]]; then
  echo ""
  echo "Проверка не прошла. На VPS:"
  echo "  journalctl -u phantom-proxy -f"
  echo "  journalctl -u stealth-gate -f"
  echo "Ищите: fake TLS отклонён, ECH extension, secret mismatch"
  exit 1
fi

echo ""
echo "✅ Прокси доступны по TCP/TLS"
