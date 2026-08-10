# CI/CD — GitHub Actions

Непрерывная интеграция настроена в [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).

## Триггеры

- Push и pull request в ветку `main`
- При новом push в PR предыдущий запуск отменяется (`concurrency`)

## Jobs

| Job | Что проверяет |
|-----|----------------|
| **flutter** | `flutter analyze --no-fatal-infos`, `flutter test` |
| **tdlib-linux** | Сборка модифицированного TDLib, артефакт `libtdjson.so` |

### flutter

1. Копирует `.env.example` → `.env` (секреты в CI не нужны)
2. `flutter pub get`
3. Статический анализ и unit-тесты

### tdlib-linux

1. Устанавливает зависимости: `build-essential`, `cmake`, `ninja-build`, `gperf`, `zlib1g-dev`, `libssl-dev`
2. Кэширует каталог `td/build` (ключ — хэш DPI-патчей и скрипта сборки)
3. Собирает TDLib: `CC=gcc CXX=g++ TD_ENABLE_LTO=OFF ./scripts/build-tdlib.sh`
4. Загружает `libtdjson.so` как артефакт (7 дней)

> **Замечание:** на `ubuntu-latest` по умолчанию `c++` может указывать на clang без `libstdc++`. В CI явно заданы `CC=gcc` и `CXX=g++`.

## Локальный запуск

```bash
# Flutter (как в CI)
./scripts/ci-flutter.sh

# TDLib
CC=gcc CXX=g++ TD_ENABLE_LTO=OFF ./scripts/build-tdlib.sh
```

## Badge

В README:

```markdown
![CI](https://github.com/RioTwWks/RioGram/actions/workflows/ci.yml/badge.svg)
```

## Дальнейшие шаги

- [ ] Job `flutter build linux` с libtdjson из артефакта
- [ ] Сборка Windows/macOS через matrix
- [ ] Публикация релизов (`.deb`, AppImage, MSIX)
