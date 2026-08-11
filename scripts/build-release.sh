#!/usr/bin/env bash
# Полная релизная сборка для текущей или указанной платформы.
#
# Использование:
#   ./scripts/build-release.sh              # автоопределение ОС
#   ./scripts/build-release.sh linux
#   VERSION=0.1.0 ./scripts/build-release.sh linux
#
# Перед запуском: .env или переменные TELEGRAM_API_* (см. scripts/generate-env.sh)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

PLATFORM="${1:-}"
VERSION="${VERSION:-0.1.0}"
OUT_DIR="${OUT_DIR:-dist}"

detect_platform() {
  case "$(uname -s)" in
    Linux) echo "linux" ;;
    Darwin) echo "macos" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *)
      echo "Не удалось определить платформу. Укажите явно: linux|macos|windows|android|ios"
      exit 1
      ;;
  esac
}

if [[ -z "${PLATFORM}" ]]; then
  PLATFORM="$(detect_platform)"
fi

echo "▶ RioGram release build: platform=${PLATFORM}, version=${VERSION}"

if [[ ! -f .env ]]; then
  ./scripts/generate-env.sh
fi

flutter pub get

build_tdlib() {
  case "${PLATFORM}" in
    linux)
      if ! command -v gcc >/dev/null; then
        ./scripts/install-linux-build-deps.sh
      fi
      CC=gcc CXX=g++ TD_ENABLE_LTO=OFF ./scripts/build-tdlib.sh
      ;;
    macos)
      ./scripts/build-tdlib-macos.sh
      ;;
    windows)
      if [[ -z "${VCPKG_ROOT:-}" && -z "${VCPKG_INSTALLATION_ROOT:-}" ]]; then
        echo "Ошибка: задайте VCPKG_ROOT для сборки TDLib на Windows"
        exit 1
      fi
      powershell.exe -File ./scripts/build-tdlib-windows.ps1
      ;;
    android)
      ./scripts/build-tdlib-android.sh
      ;;
    ios)
      ./scripts/build-tdlib-ios.sh
      ;;
    *)
      echo "Неизвестная платформа: ${PLATFORM}"
      exit 1
      ;;
  esac
}

flutter_build() {
  case "${PLATFORM}" in
    linux)
      ./scripts/copy-tdlib.sh linux
      flutter build linux --release
      ./scripts/copy-tdlib-to-bundle.sh linux
      ;;
    macos)
      ./scripts/copy-tdlib.sh macos
      flutter build macos --release
      ./scripts/copy-tdlib-to-bundle.sh macos
      ;;
    windows)
      ./scripts/copy-tdlib.sh windows
      flutter build windows --release
      ./scripts/copy-tdlib-to-bundle.sh windows
      ;;
    android)
      ./scripts/setup-android-signing.sh
      flutter build apk --release --split-per-abi
      flutter build appbundle --release
      ;;
    ios)
      ./scripts/setup-ios-signing.sh
      if [[ -f ios/ExportOptions.plist ]]; then
        flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
      else
        flutter build ios --release --no-codesign
      fi
      ;;
  esac
}

package() {
  case "${PLATFORM}" in
    windows)
      powershell.exe -File ./scripts/package-release.ps1 -Version "${VERSION}" -OutputDir "${OUT_DIR}"
      ;;
    *)
      ./scripts/package-release.sh "${PLATFORM}" "${VERSION}" "${OUT_DIR}"
      ;;
  esac
}

build_tdlib
flutter_build
package

echo ""
echo "✅ Готово: ${OUT_DIR}/"
