# Сборка RioGram на всех платформах

Руководство для разработчиков. Релизные пакеты собираются автоматически через [GitHub Actions](CI.md#релизы); здесь — локальная сборка.

## Общие шаги

1. Клонировать репозиторий и установить [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.22
2. Настроить `.env` (см. [QUICKSTART.md](QUICKSTART.md) и [SECRETS.md](SECRETS.md))
3. Собрать модифицированный TDLib с DPI-патчами
4. Скопировать `libtdjson` в проект (`scripts/copy-tdlib.sh`)
5. `flutter build <platform> --release`
6. Упаковать (`scripts/package-release.sh` / `package-release.ps1`)

Универсальный скрипт (автоопределение ОС):

```bash
./scripts/build-release.sh
# или явно:
./scripts/build-release.sh linux
```

---

## Linux (x64)

### Зависимости

```bash
./scripts/install-linux-build-deps.sh
```

Скрипт поддерживает Debian/Ubuntu (`apt`) и Arch Linux (`pacman`). На Arch вручную:

```bash
sudo pacman -S --needed base-devel cmake ninja gperf zlib openssl clang pkgconf gtk3 libunwind gstreamer gst-plugins-base util-linux xz zip perl php
```

### Сборка

```bash
./scripts/generate-env.sh          # или cp .env.example .env
CC=gcc CXX=g++ TD_ENABLE_LTO=OFF ./scripts/build-tdlib.sh
./scripts/copy-tdlib.sh linux
flutter pub get
flutter build linux --release
./scripts/copy-tdlib-to-bundle.sh linux
./scripts/package-release.sh linux 0.1.0 dist
```

Результат: `dist/RioGram-0.1.0-linux-x64.tar.gz`

Запуск из распакованного бандла:

```bash
tar -xzf RioGram-0.1.0-linux-x64.tar.gz -C riogram
./riogram/riogram
```

---

## Windows (x64)

### Зависимости

- Visual Studio 2022 (Desktop development with C++)
- [vcpkg](https://vcpkg.io) с пакетом OpenSSL (`vcpkg.json` в корне)
- Flutter для Windows

### Сборка (PowerShell)

```powershell
$env:VCPKG_ROOT = "C:\path\to\vcpkg"
.\scripts\build-tdlib-windows.ps1
```

```bash
./scripts/copy-tdlib.sh windows
flutter build windows --release
./scripts/copy-tdlib-to-bundle.sh windows
```

```powershell
.\scripts\package-release.ps1 -Version 0.1.0 -OutputDir dist
```

Результат: `dist/RioGram-0.1.0-windows-x64.zip` — запуск `riogram.exe`

---

## macOS (Apple Silicon)

### Зависимости

```bash
brew install cmake gperf openssl@3
```

### Сборка

```bash
./scripts/build-tdlib-macos.sh
./scripts/copy-tdlib.sh macos
flutter build macos --release
./scripts/copy-tdlib-to-bundle.sh macos
./scripts/package-release.sh macos 0.1.0 dist
```

Результат: `dist/RioGram-0.1.0-macos-arm64.zip` — `riogram.app`

> Intel Mac: требуется отдельная сборка TDLib с `x86_64` (пока CI собирает только arm64).

---

## Android (APK / AAB)

### Зависимости

- Android SDK + NDK (через `flutter doctor --android-licenses`)
- Java 17
- `php`, `perl` (для скриптов TDLib)

```bash
./scripts/install-linux-build-deps.sh   # Linux/macOS
flutter precache --android
```

### Сборка

```bash
./scripts/build-tdlib-android.sh
flutter build apk --release --split-per-abi
flutter build appbundle --release
./scripts/package-release.sh android 0.1.0 dist
```

Результат: `dist/RioGram-0.1.0-android-arm64.apk`, `.aab`

Подпись release (локально и CI): **[SIGNING.md](SIGNING.md)**

1. Создайте keystore и `android/key.properties` (шаблон `android/key.properties.example`)
2. Или задайте `ANDROID_*` secrets в GitHub для автоматической подписи в Release workflow

Без `key.properties` / secrets APK подписан debug-ключом (только для тестов, не для Play Store).

---

## iOS

Только на macOS с Xcode. Подробно: **[SIGNING.md](SIGNING.md)**

```bash
./scripts/build-tdlib-ios.sh
# С подписью (после setup-ios-signing.sh или настройки в Xcode):
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
# Без подписи:
flutter build ios --release --no-codesign
./scripts/package-release.sh ios 0.1.0 dist
```

Результат: `dist/RioGram-0.1.0-ios.ipa` (подписанный) или `…-ios-unsigned.zip`

---

## Пути libtdjson

| Платформа | Куда копирует `copy-tdlib.sh` |
|-----------|-------------------------------|
| Linux | `linux/runner/libtdjson.so` |
| Windows | `windows/runner/tdjson.dll` |
| macOS | `macos/Runner/libtdjson.dylib` |
| Android | `android/app/src/main/jniLibs/<abi>/libtdjson.so` |
| iOS | `ios/Frameworks/libtdjson.a` (через `build-tdlib-ios.sh`) |

Нативные библиотеки **не коммитятся** в git — собираются локально или в CI.

---

## GitHub Actions

| Workflow | Назначение |
|----------|------------|
| [ci.yml](../.github/workflows/ci.yml) | analyze, test, TDLib, **Flutter Linux build** |
| [release.yml](../.github/workflows/release.yml) | пакеты для всех платформ при Release |

Секреты: [SECRETS.md](SECRETS.md) · Подпись: [SIGNING.md](SIGNING.md)

---

## Устранение неполадок

| Ошибка | Решение |
|--------|---------|
| `libtdjson не найден` | `./scripts/build-tdlib.sh` + `copy-tdlib.sh <platform>` |
| **ПК зависает на ~90% сборки TDLib** | OOM на этапе LTO-линковки. См. ниже |
| `cannot find -lstdc++` (Linux) | `CC=gcc CXX=g++` при сборке TDLib |
| `TELEGRAM_API_ID` в release CI | Добавьте secrets в GitHub |
| Android NDK не найден | `flutter doctor`, установите NDK через sdkmanager |

### Зависание / hard reset при сборке TDLib

Сборка TDLib — сотни тяжёлых C++ translation units. На **~90%** часто начинается **линковка** `libtdjson.so`. С включённым LTO (`-DTD_ENABLE_LTO=ON`) линкер может занять **8–16+ GB RAM** и заморозить систему без swap.

**Безопасная сборка (рекомендуется локально):**

```bash
CC=gcc CXX=g++ JOBS=1 TD_ENABLE_LTO=OFF ./scripts/build-tdlib.sh
```

Скрипт по умолчанию уже ставит `TD_ENABLE_LTO=OFF` и ограничивает `JOBS` по объёму RAM (~1.8 GB на job).

| RAM | Рекомендуемые `JOBS` |
|-----|----------------------|
| ≤ 8 GB | `JOBS=1` |
| 8–16 GB | `JOBS=2` |
| 16+ GB | авто (или `JOBS=$(nproc)`) |

Если после жёсткой перезагрузки сборка ведёт себя странно:

```bash
rm -rf td/build
CC=gcc CXX=g++ JOBS=1 TD_ENABLE_LTO=OFF ./scripts/build-tdlib.sh
```

Дополнительно: включите swap (4–8 GB), закройте браузер и IDE на время линковки.
