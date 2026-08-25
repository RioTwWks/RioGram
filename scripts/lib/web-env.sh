# shellcheck shell=bash
# Load /etc/riogram/web.env and resolve EU backend base URL.
# Source from verify/deploy scripts:
#   source "$(dirname ...)/lib/web-env.sh"
#   BASE="$(riogram_eu_backend_base)"

load_riogram_web_env() {
  local env_file="${RIOGRAM_ENV_FILE:-/etc/riogram/web.env}"
  if [[ -f "${env_file}" ]]; then
    # shellcheck disable=SC1090
    set -a
    # shellcheck source=/dev/null
    source "${env_file}"
    set +a
  fi
}

# Echo listen port for EU aggregator nginx (default 8080).
riogram_eu_backend_port() {
  load_riogram_web_env
  local port="${EU_BACKEND_PORT:-${TUNNEL_EU_PORT:-8080}}"
  if ! [[ "${port}" =~ ^[0-9]+$ ]]; then
    port=8080
  fi
  echo "${port}"
}

# Echo http://127.0.0.1:<port> unless WEB_ROOT is already set by caller.
riogram_eu_backend_base() {
  if [[ -n "${WEB_ROOT:-}" ]]; then
    echo "${WEB_ROOT}"
    return 0
  fi
  echo "http://127.0.0.1:$(riogram_eu_backend_port)"
}
