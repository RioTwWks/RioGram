# Синхронизация форка TDLib с upstream

RioGram хранит модифицированный TDLib в каталоге `td/`. Базовая версия upstream зафиксирована в [`td/upstream-base.json`](../td/upstream-base.json).

Автоматическая проверка новых версий: workflow [`.github/workflows/tdlib-upstream-sync.yml`](../.github/workflows/tdlib-upstream-sync.yml) (еженедельно + вручную).

## Текущая база

| Поле | Значение |
|------|----------|
| Upstream | [tdlib/td](https://github.com/tdlib/td) |
| Версия | см. `td/upstream-base.json` → `version` |
| Commit | см. `td/upstream-base.json` → `commit` |
| Патчи DPI | [TDLIB_PATCHES.md](TDLIB_PATCHES.md) |

Проверить локально:

```bash
./scripts/check-tdlib-upstream.sh
./scripts/check-tdlib-upstream.sh --json
```

## Когда merge обязателен

- Появился новый тег/commit `Update version to X.Y.Z` в upstream
- Критичный security/fix в MTProto/TLS слое
- Регрессия после обновления Telegram API (новые `td_api` методы)

Косметические правки upstream без смены версии можно откладывать.

## Чеклист merge upstream → `td/`

### 1. Подготовка

- [ ] Прочитать [release notes / changelog](https://github.com/tdlib/td/commits/master) между текущим `commit` и целевым тегом
- [ ] Создать ветку `cursor/tdlib-merge-X.Y.Z-2af3`
- [ ] Убедиться, что локальная сборка текущего `td/` проходит: `./scripts/build-tdlib.sh`

### 2. Импорт upstream

```bash
UPSTREAM=/tmp/td-upstream
git clone --depth=1 https://github.com/tdlib/td.git "$UPSTREAM"
cd "$UPSTREAM"
git fetch --depth=1 origin <TARGET_COMMIT>
git checkout <TARGET_COMMIT>
```

Слияние (выберите подход):

**Вариант A — чистый vendor (рекомендуется для крупных апдейтов):**

1. Сохранить список RioGram-файлов с `DPI_BYPASS` (см. ниже)
2. Заменить содержимое `td/` на upstream checkout
3. Вручную перенести патчи из сохранённого diff

**Вариант B — git merge внутри `td/` (если `td/` — отдельный git clone):**

```bash
cd td
git remote add upstream https://github.com/tdlib/td.git  # один раз
git fetch upstream
git merge <TARGET_COMMIT>
```

### 3. Перенос патчей `DPI_BYPASS`

Обязательные файлы (см. [TDLIB_PATCHES.md](TDLIB_PATCHES.md)):

| Файл | Назначение |
|------|------------|
| `td/td/mtproto/dpi_bypass/DpiBypass.h` | API, флаги, профили TLS |
| `td/td/mtproto/dpi_bypass/DpiBypass.cpp` | DRS, фрагментация, ротация |
| `td/td/mtproto/TlsInit.cpp` | ClientHello профили |
| `td/td/mtproto/TcpTransport.cpp` | Динамический размер TLS records |
| `td/CMakeLists.txt` | `dpi_bypass/DpiBypass.cpp` в sources |
| `td/td/telegram/net/ConnectionCreator.cpp` | `RioGram:Transport` proxy chain |

Найти все маркеры:

```bash
rg 'DPI_BYPASS|RioGram:Transport' td/
```

После merge **каждый** патч должен остаться с комментарием `// DPI_BYPASS:`.

### 4. Разрешение конфликтов

Типичные зоны конфликтов:

- `td/td/mtproto/TlsInit.cpp` — частые изменения TLS в upstream
- `td/td/mtproto/TcpTransport.cpp` — размер буферов
- `td/td/telegram/net/ConnectionCreator.cpp` — прокси и транспорт
- `td/CMakeLists.txt` — списки исходников

Стратегия: принять upstream-логику, затем поверх неё заново применить RioGram diff (не терять `DpiBypass` вызовы).

### 5. Сборка и регрессия

```bash
TD_ENABLE_LTO=OFF ./scripts/build-tdlib.sh
./scripts/copy-tdlib.sh linux
flutter test
```

Ручная проверка DPI (см. [PROXY.md](PROXY.md), [STEALTH.md](STEALTH.md)):

- [ ] Fake TLS MTProto-прокси: handshake без `reject_fronting`
- [ ] Стабильный режим `kDpiBypassStableProxyMode = true` (Yandex/VK профиль по SNI)
- [ ] Полный режим `kDpiBypassStableProxyMode = false`: фрагментация + DRS
- [ ] Системный HTTP/SOCKS transport proxy (`RioGram:Transport`)
- [ ] `pingProxy` / failover в UI

### 6. Обновление метаданных

- [ ] `td/CMakeLists.txt` — версия совпадает с upstream target
- [ ] `td/upstream-base.json` — новые `version`, `commit`, `commit_date`, `synced_at`
- [ ] `docs/TDLIB_PATCHES.md` — если изменились файлы/флаги
- [ ] CI: job `tdlib-linux` зелёный

### 7. Коммит

```text
chore(tdlib): merge upstream vX.Y.Z (aabbccdd)

- Reapply DPI_BYPASS patches
- Update td/upstream-base.json
```

## CI и уведомления

Workflow `tdlib-upstream-sync.yml`:

1. Раз в неделю читает `project(TDLib VERSION …)` из `tdlib/td` `master`
2. Сравнивает с `td/upstream-base.json`
3. Если версия новее — создаёт Issue с чеклистом (без дубликатов на ту же версию)

Ручной запуск: **Actions → TDLib upstream sync → Run workflow**.

## Ссылки

- [Upstream TDLib](https://github.com/tdlib/td)
- [Сборка TDLib](BUILD.md)
- [Патчи DPI](TDLIB_PATCHES.md)
- [CI](CI.md)
