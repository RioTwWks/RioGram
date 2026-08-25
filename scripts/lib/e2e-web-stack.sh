#!/usr/bin/env bash
# Shared local EU backend stack for Web E2E (§8.4–8.6).
# Source: source "${ROOT_DIR}/scripts/lib/e2e-web-stack.sh"

e2e_stack_up() {
  E2E_ROOT="${E2E_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
  E2E_BACKEND_PORT="${EU_BACKEND_PORT:-8080}"
  E2E_WEB_ROOT="${E2E_WEB_ROOT:-http://127.0.0.1:${E2E_BACKEND_PORT}}"
  E2E_TMP="/tmp/riogram-eu-test"
  E2E_NGINX_CONF="${E2E_ROOT}/deploy/nginx/riogram-eu-backend.conf"
  E2E_WEB_SRC="${E2E_ROOT}/build/web"

  command -v nginx >/dev/null || { echo "nginx required" >&2; return 1; }

  if [[ ! -f "${E2E_WEB_SRC}/index.html" ]]; then
    SKIP_TDWEB_CHECK=1 "${E2E_ROOT}/scripts/build-web.sh"
  fi

  if [[ ! -x "${E2E_ROOT}/bin/riogram-wss-proxy" ]]; then
    "${E2E_ROOT}/scripts/build-wss-proxy.sh"
  fi

  mkdir -p "${E2E_TMP}/log" "${E2E_TMP}/nginx-body" "${E2E_TMP}/web"
  cp -a "${E2E_WEB_SRC}/." "${E2E_TMP}/web/"

  sed \
    -e "s|__EU_BACKEND_PORT__|${E2E_BACKEND_PORT}|g" \
    -e "s|/var/log/riogram|${E2E_TMP}/log|g" \
    -e "s|/run/riogram-eu-backend.pid|${E2E_TMP}/nginx.pid|g" \
    -e "s|/opt/riogram/web|${E2E_TMP}/web|g" \
    "${E2E_NGINX_CONF}" \
    | sed "/^http {/a\\
    client_body_temp_path ${E2E_TMP}/nginx-body;\\
    proxy_temp_path ${E2E_TMP}/nginx-body;\\
    fastcgi_temp_path ${E2E_TMP}/nginx-body;\\
    uwsgi_temp_path ${E2E_TMP}/nginx-body;\\
    scgi_temp_path ${E2E_TMP}/nginx-body;" \
    >"${E2E_TMP}/nginx.conf"

  WSS_PROXY_LISTEN=127.0.0.1:5001 "${E2E_ROOT}/bin/riogram-wss-proxy" &
  E2E_WSS_PID=$!
  sleep 0.5

  nginx -c "${E2E_TMP}/nginx.conf"
  E2E_NGINX_PID="$(cat "${E2E_TMP}/nginx.pid")"
  sleep 0.3

  export WEB_ROOT="${E2E_WEB_ROOT}"
  export EU_BACKEND_PORT="${E2E_BACKEND_PORT}"
}

e2e_stack_down() {
  [[ -n "${E2E_WSS_PID:-}" ]] && kill "${E2E_WSS_PID}" 2>/dev/null || true
  [[ -n "${E2E_NGINX_PID:-}" ]] && kill "${E2E_NGINX_PID}" 2>/dev/null || true
  rm -rf /tmp/riogram-eu-test 2>/dev/null || true
}
