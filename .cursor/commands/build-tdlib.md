---
command: Собрать модифицированный TDLib для всех платформ
---

# Сборка TDLib

Модифицированный TDLib с патчами `DPI_BYPASS` в каталоге `td/`.

## Linux (основной путь)

```bash
sudo apt-get install -y build-essential cmake ninja-build gperf zlib1g-dev libssl-dev
CC=gcc CXX=g++ TD_ENABLE_LTO=OFF ./scripts/build-tdlib.sh
./scripts/copy-tdlib.sh linux
test -f td/build/install/lib/libtdjson.so && echo OK
```

По умолчанию: `TD_ENABLE_LTO=OFF`, `JOBS` ограничен по RAM.  
При зависании на ~90%: `JOBS=1 TD_ENABLE_LTO=OFF ./scripts/build-tdlib.sh`

## Другие платформы

| Платформа | Скрипт | Копирование |
|-----------|--------|-------------|
| macOS | `scripts/build-tdlib-macos.sh` | `./scripts/copy-tdlib.sh macos` |
| Windows | `scripts/build-tdlib-windows.ps1` | `./scripts/copy-tdlib.sh windows` |
| Android | `scripts/build-tdlib-android.sh` | `./scripts/copy-tdlib.sh android` |
| iOS | `scripts/build-tdlib-ios.sh` | `./scripts/copy-tdlib.sh ios` |

Переменные: `TD_ENABLE_LTO`, `JOBS`, `CMAKE_BUILD_TYPE`, `CC`, `CXX`.

## После сборки

```bash
flutter pub get
flutter run -d linux    # или windows / macos / android / ios
```

## Upstream и патчи

- База upstream: [`td/upstream-base.json`](../../td/upstream-base.json)
- Патчи: [docs/TDLIB_PATCHES.md](../../docs/TDLIB_PATCHES.md)
- Merge с upstream: [@tdlib-upstream](tdlib-upstream.md)

После изменений в `td/**/*.cpp` обязательно:

1. Маркер `// DPI_BYPASS:` на каждом патче
2. `./scripts/build-tdlib.sh`
3. Проверка прокси (PhantomProxy + StealthGate)

Подробнее: [docs/BUILD.md](../../docs/BUILD.md)
