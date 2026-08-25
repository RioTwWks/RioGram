---
command: Синхронизация форка TDLib с upstream (§7.7)
---

# TDLib upstream sync — §7.7

RioGram хранит модифицированный TDLib в `td/`. Базовая версия upstream зафиксирована в [`td/upstream-base.json`](../../td/upstream-base.json).

## Документация

| Файл | Содержание |
|------|------------|
| [docs/TDLIB_UPSTREAM_SYNC.md](../../docs/TDLIB_UPSTREAM_SYNC.md) | Чеклист merge upstream → `td/` |
| [docs/TDLIB_PATCHES.md](../../docs/TDLIB_PATCHES.md) | Список DPI_BYPASS патчей |
| [docs/CI.md](../../docs/CI.md) | Workflow `tdlib-upstream-sync.yml` |

## Проверить, есть ли новая версия

```bash
./scripts/check-tdlib-upstream.sh
./scripts/check-tdlib-upstream.sh --json
```

- exit `0` — база актуальна (или RioGram ahead)
- exit `2` — upstream новее → нужен merge

## Автоматические уведомления

Workflow [`.github/workflows/tdlib-upstream-sync.yml`](../../.github/workflows/tdlib-upstream-sync.yml):

- расписание: понедельник 06:00 UTC
- ручной запуск: **Actions → TDLib upstream sync → Run workflow**
- при новой версии создаётся GitHub Issue с чеклистом

## Merge (кратко)

1. Ветка `cursor/tdlib-merge-X.Y.Z-2af3`
2. Импорт upstream commit из Issue / `check-tdlib-upstream.sh --json`
3. Перенести все `DPI_BYPASS` и `RioGram:Transport` (см. `rg 'DPI_BYPASS|RioGram:Transport' td/`)
4. `TD_ENABLE_LTO=OFF ./scripts/build-tdlib.sh`
5. Ручная проверка Fake TLS / transport proxy ([PROXY.md](../../docs/PROXY.md), [STEALTH.md](../../docs/STEALTH.md))
6. Обновить `td/upstream-base.json`, `flutter test test/tdlib_upstream_manifest_test.dart`
7. CI `tdlib-linux` зелёный

Сборка после merge: [@build-tdlib](build-tdlib.md)
