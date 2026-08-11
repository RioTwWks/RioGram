#!/usr/bin/env bash
# Портативное копирование файлов (GNU install -D недоступен на macOS BSD).
copy_into() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "${dst}")"
  cp -f "${src}" "${dst}"
}
