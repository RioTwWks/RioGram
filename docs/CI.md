# CI/CD — GitHub Actions

## CI (непрерывная интеграция)

Файл: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml)

| Job | Что проверяет |
|-----|----------------|
| **flutter** | `flutter analyze --no-fatal-infos`, `flutter test` |
| **tdlib-linux** | Сборка модифицированного TDLib, артефакт `libtdjson.so` |

Триггеры: push и pull request в `main`.

## Релизы

Файл: [`.github/workflows/release.yml`](../.github/workflows/release.yml)

При **публикации GitHub Release** (`release: published`) параллельно собираются пакеты для всех платформ и прикрепляются к релизу.

| Job | Runner | Артефакт |
|-----|--------|----------|
| **build-linux** | `ubuntu-latest` | `RioGram-{ver}-linux-x64.tar.gz` |
| **build-windows** | `windows-latest` | `RioGram-{ver}-windows-x64.zip` |
| **build-macos** | `macos-latest` | `RioGram-{ver}-macos-arm64.zip` |
| **build-android** | `ubuntu-latest` | APK (arm64, armv7) + AAB |
| **build-ios** | `macos-latest` | `RioGram-{ver}-ios-unsigned.zip` |

### Как выпустить релиз

1. Обновите `version` в `pubspec.yaml`
2. Создайте и запушьте тег: `git tag v0.1.0 && git push origin v0.1.0`
3. На GitHub: **Releases → Draft a new release** → выберите тег → **Publish release**
4. Дождитесь завершения workflow **Release** (сборка TDLib + Flutter может занять 30–60 мин)

### Ручной запуск

**Actions → Release → Run workflow** — сборка без прикрепления к релизу (артефакты в run).

### Скрипты

| Скрипт | Назначение |
|--------|------------|
| `scripts/ci-flutter.sh` | Локальный CI (analyze + test) |
| `scripts/build-tdlib.sh` | TDLib Linux |
| `scripts/build-tdlib-macos.sh` | TDLib macOS |
| `scripts/build-tdlib-windows.ps1` | TDLib Windows (vcpkg OpenSSL) |
| `scripts/build-tdlib-android.sh` | TDLib Android (JSON + jniLibs) |
| `scripts/build-tdlib-ios.sh` | TDLib iOS static (`ios/Frameworks/libtdjson.a`) |
| `scripts/copy-tdlib.sh` | Копирование libtdjson в проект перед `flutter build` |
| `scripts/copy-tdlib-to-bundle.sh` | Копирование libtdjson в готовый бандл (desktop) |
| `scripts/package-release.sh` | Упаковка Linux/macOS/Android/iOS |
| `scripts/package-release.ps1` | Упаковка Windows |

### Замечания

- **Windows**: OpenSSL через [vcpkg](https://vcpkg.io) (`vcpkg.json` в корне)
- **Android**: OpenSSL и TDLib кэшируются; первый запуск долгий (~20–40 мин)
- **iOS**: сборка без подписи (`--no-codesign`); для App Store нужна ручная подпись
- **macOS**: runner `macos-latest` — Apple Silicon (arm64)
- На Linux в CI: `CC=gcc CXX=g++` (clang по умолчанию может не найти `libstdc++`)

## Локальный запуск CI

```bash
./scripts/ci-flutter.sh
CC=gcc CXX=g++ TD_ENABLE_LTO=OFF ./scripts/build-tdlib.sh
```

Секреты для релизных сборок: [docs/SECRETS.md](SECRETS.md)

## Badge

```markdown
![CI](https://github.com/RioTwWks/RioGram/actions/workflows/ci.yml/badge.svg)
```
