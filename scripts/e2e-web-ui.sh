#!/usr/bin/env bash
# Playwright UI smoke tests (§8.6). Requires running stack at E2E_BASE_URL.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
E2E_DIR="${ROOT_DIR}/e2e/web"
E2E_BASE_URL="${E2E_BASE_URL:-http://127.0.0.1:8080}"

if ! command -v node >/dev/null; then
  echo "node.js required for Playwright E2E" >&2
  exit 1
fi

cd "${E2E_DIR}"
if [[ ! -d node_modules/@playwright/test ]]; then
  npm install --no-save
  npx playwright install chromium
fi

export E2E_BASE_URL
npx playwright test "$@"

echo "✅ Playwright UI smoke passed"
