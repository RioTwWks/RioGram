---
command: Собрать модифицированный TDLib для всех платформ
---

# Сборка TDLib

1. Установить зависимости (Linux):
   ```bash
   sudo apt-get install -y build-essential cmake ninja-build gperf zlib1g-dev libssl-dev
   ```
2. Из корня репозитория:
   ```bash
   CC=gcc CXX=g++ ./scripts/build-tdlib.sh
   ```
   По умолчанию: `TD_ENABLE_LTO=OFF`, `JOBS` ограничен по RAM.
   При зависании ПК на ~90%: `JOBS=1 TD_ENABLE_LTO=OFF ./scripts/build-tdlib.sh`
   Переменные: `TD_ENABLE_LTO`, `JOBS`, `CMAKE_BUILD_TYPE`.
3. Скопировать собранные библиотеки в `flutter/`:
   - Windows: `install/bin/tdjson.dll` → `windows/runner/`
   - macOS: `install/lib/libtdjson.dylib` → `macos/Runner/`
   - Linux: `install/lib/libtdjson.so` → `linux/runner/`
   - Android: `install/lib/armeabi-v7a/libtdjson.so` и т.д. → `android/app/src/main/jniLibs/`
   - iOS: `install/lib/libtdjson.a` → `ios/Frameworks/`
4. Пересобрать Flutter-приложение.
