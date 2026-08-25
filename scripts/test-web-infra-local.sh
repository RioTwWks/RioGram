#!/usr/bin/env bash
# Локальная симуляция EU backend stack (§8.4–8.5) без SSH.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NGINX_CONF="${ROOT_DIR}/deploy/nginx/riogram-eu-backend.conf"
WEB_SRC="${ROOT_DIR}/build/web"

command -v nginx >/dev/null || { echo "nginx required" >&2; exit 1; }

if [[ ! -f "${WEB_SRC}/index.html" ]]; then
  SKIP_TDWEB_CHECK=1 "${ROOT_DIR}/scripts/build-web.sh"
fi

if [[ ! -x "${ROOT_DIR}/bin/riogram-wss-proxy" ]]; then
  "${ROOT_DIR}/scripts/build-wss-proxy.sh"
fi

cleanup() {
  [[ -n "${WSS_PID:-}" ]] && kill "${WSS_PID}" 2>/dev/null || true
  [[ -n "${NGINX_PID:-}" ]] && kill "${NGINX_PID}" 2>/dev/null || true
  rm -rf /tmp/riogram-eu-test
}
trap cleanup EXIT

mkdir -p /tmp/riogram-eu-test/log /tmp/riogram-eu-test/nginx-body /tmp/riogram-eu-test/web
cp -a "${WEB_SRC}/." /tmp/riogram-eu-test/web/

sed "s|/var/log/riogram|/tmp/riogram-eu-test/log|g" "${NGINX_CONF}" \
  | sed "s|/run/riogram-eu-backend.pid|/tmp/riogram-eu-test/nginx.pid|g" \
  | sed "s|/opt/riogram/web|/tmp/riogram-eu-test/web|g" \
  | sed "/^http {/a\\
    client_body_temp_path /tmp/riogram-eu-test/nginx-body;\\
    proxy_temp_path /tmp/riogram-eu-test/nginx-body;\\
    fastcgi_temp_path /tmp/riogram-eu-test/nginx-body;\\
    uwsgi_temp_path /tmp/riogram-eu-test/nginx-body;\\
    scgi_temp_path /tmp/riogram-eu-test/nginx-body;" \
  >/tmp/riogram-eu-test/nginx.conf

WSS_PROXY_LISTEN=127.0.0.1:5001 "${ROOT_DIR}/bin/riogram-wss-proxy" &
WSS_PID=$!
sleep 0.5

nginx -c /tmp/riogram-eu-test/nginx.conf
NGINX_PID=$(cat /tmp/riogram-eu-test/nginx.pid)
sleep 0.3

WEB_ROOT=http://127.0.0.1:8080 "${ROOT_DIR}/scripts/verify-web-deploy.sh"

echo "✅ Local EU backend + Web deploy OK"
