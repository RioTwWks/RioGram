---
command: Собрать релизные пакеты для всех платформ
---

# Релизные сборки

Автоматически запускаются при публикации GitHub Release (workflow `.github/workflows/release.yml`).

## Создание релиза

1. Обновите версию в `pubspec.yaml` (`version: X.Y.Z+N`)
2. Создайте тег и релиз на GitHub:
   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```
3. На GitHub: **Releases → Draft a new release** → выберите тег → **Publish release**
4. Actions соберёт и прикрепит артефакты:
   - `RioGram-X.Y.Z-linux-x64.tar.gz`
   - `RioGram-X.Y.Z-windows-x64.zip`
   - `RioGram-X.Y.Z-macos-arm64.zip`
   - `RioGram-X.Y.Z-android-arm64.apk` (+ armv7, aab)
   - `RioGram-X.Y.Z-ios-unsigned.zip`

## Ручной запуск (без релиза)

**Actions → Release → Run workflow** — артефакты появятся в run, но не прикрепятся к релизу.

## Локальная сборка (Linux)

```bash
./scripts/install-linux-build-deps.sh
CC=gcc CXX=g++ TD_ENABLE_LTO=OFF ./scripts/build-tdlib.sh
./scripts/copy-tdlib.sh linux
flutter build linux --release
./scripts/copy-tdlib-to-bundle.sh linux
./scripts/package-release.sh linux 0.1.0 dist
```

Подробнее: [docs/CI.md](../../docs/CI.md#релизы)
