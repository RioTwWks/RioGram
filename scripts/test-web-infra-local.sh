#!/usr/bin/env bash
# Локальная симуляция EU backend stack (§8.4) без SSH.
# Проверяет nginx eu-backend → wss-proxy + static placeholder.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NGINX_CONF="${ROOT_DIR}/deploy/nginx/riogram-eu-backend.conf"

command -v nginx >/dev/null || { echo "nginx required" >&2; exit 1; }

if [[ ! -x "${ROOT_DIR}/bin/riogram-wss-proxy" ]]; then
  "${ROOT_DIR}/scripts/build-wss-proxy.sh"
fi

cleanup() {
  [[ -n "${WSS_PID:-}" ]] && kill "${WSS_PID}" 2>/dev/null || true
  [[ -n "${STATIC_PID:-}" ]] && kill "${STATIC_PID}" 2>/dev/null || true
  [[ -n "${NGINX_PID:-}" ]] && kill "${NGINX_PID}" 2>/dev/null || true
  rm -rf /tmp/riogram-eu-test
}
trap cleanup EXIT

mkdir -p /tmp/riogram-eu-test/log /tmp/riogram-eu-test/nginx-body
sed "s|/var/log/riogram|/tmp/riogram-eu-test/log|g" "${NGINX_CONF}" \
  | sed "s|/run/riogram-eu-backend.pid|/tmp/riogram-eu-test/nginx.pid|g" \
  | sed "/^http {/a\\
    client_body_temp_path /tmp/riogram-eu-test/nginx-body;\\
    proxy_temp_path /tmp/riogram-eu-test/nginx-body;\\
    fastcgi_temp_path /tmp/riogram-eu-test/nginx-body;\\
    uwsgi_temp_path /tmp/riogram-eu-test/nginx-body;\\
    scgi_temp_path /tmp/riogram-eu-test/nginx-body;" \
  >/tmp/riogram-eu-test/nginx.conf

echo "test" >/tmp/riogram-eu-test/index.html

WSS_PROXY_LISTEN=127.0.0.1:5001 "${ROOT_DIR}/bin/riogram-wss-proxy" &
WSS_PID=$!
python3 -m http.server 5000 --bind 127.0.0.1 --directory /tmp/riogram-eu-test >/dev/null 2>&1 &
STATIC_PID=$!
sleep 0.5

nginx -c /tmp/riogram-eu-test/nginx.conf
NGINX_PID=$(cat /tmp/riogram-eu-test/nginx.pid)
sleep 0.3

echo -n "GET :8080/health... "
curl -sf http://127.0.0.1:8080/health >/dev/null && echo OK

echo -n "GET :8080/ (static)... "
curl -sf http://127.0.0.1:8080/ | grep -q test && echo OK

echo ""
echo "✅ Local EU backend stack OK"
