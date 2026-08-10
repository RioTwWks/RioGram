---
command: Собрать модифицированный TDLib для всех платформ
---

# Сборка TDLib

1. Перейти в папку `td/`
2. Выполнить:
   ```bash
   mkdir -p build && cd build
   cmake -DCMAKE_BUILD_TYPE=Release -DTD_ENABLE_LTO=ON ..
   cmake --build . --target install --parallel $(nproc)
   ```
3. Скопировать собранные библиотеки в `flutter/`:
   - Windows: `install/bin/tdjson.dll` → `windows/runner/`
   - macOS: `install/lib/libtdjson.dylib` → `macos/Runner/`
   - Linux: `install/lib/libtdjson.so` → `linux/runner/`
   - Android: `install/lib/armeabi-v7a/libtdjson.so` и т.д. → `android/app/src/main/jniLibs/`
   - iOS: `install/lib/libtdjson.a` → `ios/Frameworks/`
4. Пересобрать Flutter-приложение.
