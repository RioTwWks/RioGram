#!/usr/bin/env bash
# Локальная симуляция EU backend stack (§8.4–8.5).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/e2e-web-stack.sh"

trap e2e_stack_down EXIT

e2e_stack_up
WEB_ROOT="${E2E_WEB_ROOT}" "${ROOT_DIR}/scripts/verify-web-deploy.sh"

echo "✅ Local EU backend + Web deploy OK"
