---
command: Запустить локальные проверки CI (Flutter)
---

# CI — локальный запуск

Повторяет job **flutter** из `.github/workflows/ci.yml`.

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

Подробнее: [docs/CI.md](../../docs/CI.md)
