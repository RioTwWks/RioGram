#!/usr/bin/env bash
# Automated Web E2E suite (§8.6) — local stack + WSS stability + UI smoke.
#
# Usage:
#   ./scripts/run-web-e2e.sh
#   E2E_SKIP_UI=1 ./scripts/run-web-e2e.sh
#   E2E_SKIP_WSS=1 ./scripts/run-web-e2e.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/e2e-web-stack.sh"

cleanup() {
  e2e_stack_down
}
trap cleanup EXIT

echo "==> Starting local EU+Web stack"
e2e_stack_up

echo "==> Deploy verification"
WEB_ROOT="${E2E_WEB_ROOT}" "${ROOT_DIR}/scripts/verify-web-deploy.sh"

if [[ "${E2E_SKIP_WSS:-0}" != "1" ]]; then
  echo "==> WSS stability (${WSS_STABILITY_SECONDS:-65}s)"
  WSS_URL="ws://127.0.0.1:8080/venus.web.telegram.org/apiws" \
    WSS_STABILITY_SECONDS="${WSS_STABILITY_SECONDS:-65}" \
    "${ROOT_DIR}/scripts/e2e-wss-stability.sh"
fi

if [[ "${E2E_SKIP_UI:-0}" != "1" ]]; then
  echo "==> Playwright UI smoke"
  E2E_BASE_URL="${E2E_WEB_ROOT}" "${ROOT_DIR}/scripts/e2e-web-ui.sh"
fi

echo ""
echo "✅ Automated Web E2E (§8.6) passed"
echo "   Manual checklist: docs/WEB_E2E.md (auth, RU access, tunnel reconnect)"
