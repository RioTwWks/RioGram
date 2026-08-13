#!/usr/bin/env bash
# Упаковывает результат flutter build в архив для релиза.
# Использование: ./scripts/package-release.sh <platform> <version> <output_dir>
set -euo pipefail

PLATFORM="${1:?}"
VERSION="${2:?}"
OUT_DIR="${3:?}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "${ROOT_DIR}/${OUT_DIR}"
OUT_DIR="$(cd "${ROOT_DIR}/${OUT_DIR}" && pwd)"
cd "${ROOT_DIR}"

NAME="RioGram-${VERSION}"

case "${PLATFORM}" in
  linux)
    bundle_dir="build/linux/x64/release/bundle"
    top_dir="${NAME}-linux-x64"
    if tar --help 2>&1 | grep -q one-top-level; then
      tar --one-top-level="${top_dir}" -czf "${OUT_DIR}/${NAME}-linux-x64.tar.gz" \
        -C "${bundle_dir}" .
    else
      tar -czf "${OUT_DIR}/${NAME}-linux-x64.tar.gz" -C "${bundle_dir}" .
    fi
    ;;
  macos)
    (cd "${ROOT_DIR}/build/macos/Build/Products/Release" && \
      zip -qr "${OUT_DIR}/${NAME}-macos-arm64.zip" riogram.app)
    ;;
  android)
    if [[ -f build/app/outputs/flutter-apk/app-arm64-v8a-release.apk ]]; then
      cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
        "${OUT_DIR}/${NAME}-android-arm64.apk"
    fi
    if [[ -f build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk ]]; then
      cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk \
        "${OUT_DIR}/${NAME}-android-armv7.apk"
    fi
    if [[ -f build/app/outputs/flutter-apk/app-release.apk ]]; then
      cp build/app/outputs/flutter-apk/app-release.apk \
        "${OUT_DIR}/${NAME}-android-universal.apk"
    fi
    if [[ -f build/app/outputs/bundle/release/app-release.aab ]]; then
      cp build/app/outputs/bundle/release/app-release.aab \
        "${OUT_DIR}/${NAME}-android.aab"
    fi
    ;;
  ios)
    if compgen -G "${ROOT_DIR}/build/ios/ipa/"*.ipa > /dev/null; then
      cp "${ROOT_DIR}"/build/ios/ipa/*.ipa "${OUT_DIR}/${NAME}-ios.ipa"
    elif [[ -d "${ROOT_DIR}/build/ios/iphoneos/Runner.app" ]]; then
      (cd "${ROOT_DIR}/build/ios/iphoneos" && \
        zip -qr "${OUT_DIR}/${NAME}-ios-unsigned.zip" Runner.app)
    else
      echo "package-release.sh: iOS артефакт не найден (ни .ipa, ни Runner.app)"
      exit 1
    fi
    ;;
  *)
    echo "package-release.sh: неизвестная платформа ${PLATFORM} (windows — через PowerShell)"
    exit 1
    ;;
esac

echo "✅ Пакет ${PLATFORM} → ${OUT_DIR}"
