#!/usr/bin/env bash
# Сравнивает зафиксированную базу TDLib (td/upstream-base.json) с upstream master.
#
# Коды выхода:
#   0 — upstream не новее локальной базы
#   1 — ошибка (нет jq, нет сети, битый manifest)
#   2 — доступна более новая версия upstream
#
# Примеры:
#   ./scripts/check-tdlib-upstream.sh
#   ./scripts/check-tdlib-upstream.sh --json
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${ROOT_DIR}/td/upstream-base.json"
CMAKE="${ROOT_DIR}/td/CMakeLists.txt"
JSON_OUTPUT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_OUTPUT=1
      shift
      ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$MANIFEST" ]]; then
  echo "Missing manifest: $MANIFEST" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

LOCAL_VERSION="$(jq -r '.version' "$MANIFEST")"
LOCAL_COMMIT="$(jq -r '.commit' "$MANIFEST")"
REPO_URL="$(jq -r '.repository' "$MANIFEST")"

if [[ ! -f "$CMAKE" ]]; then
  echo "Missing $CMAKE" >&2
  exit 1
fi

VENDOR_VERSION="$(sed -n 's/^project(TDLib VERSION \([0-9.]*\) .*/\1/p' "$CMAKE" | head -1)"
if [[ "$VENDOR_VERSION" != "$LOCAL_VERSION" ]]; then
  echo "Warning: td/CMakeLists.txt version ($VENDOR_VERSION) != upstream-base.json ($LOCAL_VERSION)" >&2
fi

fetch_upstream_version() {
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    gh api repos/tdlib/td/contents/CMakeLists.txt?ref=master --jq '.content' \
      | tr -d '\n' \
      | base64 -d \
      | sed -n 's/^project(TDLib VERSION \([0-9.]*\) .*/\1/p' \
      | head -1
    return
  fi

  curl -fsSL "https://raw.githubusercontent.com/tdlib/td/master/CMakeLists.txt" \
    | sed -n 's/^project(TDLib VERSION \([0-9.]*\) .*/\1/p' \
    | head -1
}

fetch_upstream_version_commit() {
  local version="$1"
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    gh api "search/commits?q=repo:tdlib/td+Update+version+to+${version}.&sort=committer-date&order=desc&per_page=1" \
      --jq '.items[0].sha // empty'
    return
  fi
  echo ""
}

UPSTREAM_VERSION="$(fetch_upstream_version)"
if [[ -z "$UPSTREAM_VERSION" ]]; then
  echo "Failed to read upstream TDLib version" >&2
  exit 1
fi

UPSTREAM_COMMIT="$(fetch_upstream_version_commit "$UPSTREAM_VERSION")"

version_gt() {
  local left="$1"
  local right="$2"
  if [[ "$left" == "$right" ]]; then
    return 1
  fi
  local highest
  highest="$(printf '%s\n%s\n' "$left" "$right" | sort -V | tail -1)"
  [[ "$highest" == "$left" ]]
}

STATUS="current"
if version_gt "$UPSTREAM_VERSION" "$LOCAL_VERSION"; then
  STATUS="update_available"
elif [[ "$UPSTREAM_VERSION" != "$LOCAL_VERSION" ]] && version_gt "$LOCAL_VERSION" "$UPSTREAM_VERSION"; then
  STATUS="ahead"
fi

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  jq -n \
    --arg repository "$REPO_URL" \
    --arg local_version "$LOCAL_VERSION" \
    --arg local_commit "$LOCAL_COMMIT" \
    --arg vendor_version "$VENDOR_VERSION" \
    --arg upstream_version "$UPSTREAM_VERSION" \
    --arg upstream_commit "$UPSTREAM_COMMIT" \
    --arg status "$STATUS" \
    '{
      repository: $repository,
      local: {version: $local_version, commit: $local_commit, vendor_cmake_version: $vendor_version},
      upstream: {version: $upstream_version, commit: $upstream_commit},
      status: $status
    }'
else
  echo "TDLib upstream sync"
  echo "  Repository : $REPO_URL"
  echo "  Local base : v$LOCAL_VERSION ($LOCAL_COMMIT)"
  echo "  Vendor tree: v$VENDOR_VERSION (td/CMakeLists.txt)"
  echo "  Upstream   : v$UPSTREAM_VERSION${UPSTREAM_COMMIT:+ ($UPSTREAM_COMMIT)}"
  echo "  Status     : $STATUS"
fi

case "$STATUS" in
  update_available) exit 2 ;;
  *) exit 0 ;;
esac
