---
command: Собрать релиз для текущей платформы
---

# Локальная релизная сборка

```bash
# Автоопределение ОС (linux / macos / windows)
./scripts/build-release.sh

# Явно указать платформу
VERSION=0.1.0 ./scripts/build-release.sh linux
```

Перед сборкой:
1. `.env` или `export TELEGRAM_API_ID=... TELEGRAM_API_HASH=...`
2. Зависимости платформы — см. [docs/BUILD.md](../../docs/BUILD.md)

Результат в `dist/`.

GitHub Release (все платформы): [@release](release.md)
