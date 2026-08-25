---
command: Запустить локальные проверки CI (Flutter)
---

# CI — локальный запуск

Повторяет jobs из `.github/workflows/ci.yml`.

## Flutter (job flutter)

```bash
./scripts/ci-flutter.sh
```

Или вручную:

```bash
cp .env.example .env   # если .env ещё нет
flutter pub get
flutter analyze --no-fatal-infos
flutter test
```

## TDLib (job tdlib-linux)

```bash
sudo apt-get install -y build-essential cmake ninja-build gperf zlib1g-dev libssl-dev
CC=gcc CXX=g++ TD_ENABLE_LTO=OFF ./scripts/build-tdlib.sh
test -f td/build/install/lib/libtdjson.so && echo OK
```

## Flutter Web (job flutter-web)

```bash
./scripts/build-tdweb.sh && ./scripts/copy-tdweb.sh
./scripts/build-web.sh
```

## Web E2E (job web-e2e)

```bash
WSS_STABILITY_SECONDS=30 ./scripts/run-web-e2e.sh
```

## TDLib upstream (workflow tdlib-upstream-sync)

Не входит в PR CI, но можно проверить локально:

```bash
./scripts/check-tdlib-upstream.sh
flutter test test/tdlib_upstream_manifest_test.dart
```

Подробнее: [@tdlib-upstream](tdlib-upstream.md)

---

Документация: [docs/CI.md](../../docs/CI.md), [docs/WEB_E2E.md](../../docs/WEB_E2E.md)

Связанные команды: [@web](web.md) · [@release](release.md) · [@build-tdlib](build-tdlib.md)
