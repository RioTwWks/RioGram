# RioGram Web — сборка и деплой

Обзор браузерной платформы RioGram (§8.1–8.5).

| § | Документ | Содержание |
|---|----------|------------|
| 8.1 | [WEB_POC.md](WEB_POC.md) | PoC, выбор стратегии |
| 8.2 | [WEB_TRANSPORT.md](WEB_TRANSPORT.md) | WSS hook, tdweb, Dart bridge |
| 8.3 | [WEB_PROXY.md](WEB_PROXY.md) | `riogram-wss-proxy` |
| 8.4 | [WEB_INFRA.md](WEB_INFRA.md) | SSH tunnel, Nginx RU/EU, UFW |
| 8.5 | этот документ | Flutter build + деплой |
| 8.6 | [WEB_E2E.md](WEB_E2E.md) | E2E автоматизация + ручные чеклисты |

---

## Архитектура (production)

```
Browser → https://your-domain.ru[:PORT] (RU Nginx; default :443, e.g. :16443)
       → SSH tunnel → EU nginx :8080
            ├─ /opt/riogram/web/     Flutter static (SPA)
            └─ /venus.web.telegram.org/apiws → wss-proxy :5001 → Telegram
```

---

## Требования

- Flutter stable (см. CI)
- `.env` с `TELEGRAM_API_ID` / `TELEGRAM_API_HASH` ([SECRETS.md](SECRETS.md))
- **tdweb** для TDLib в браузере: `./scripts/build-tdweb.sh && ./scripts/copy-tdweb.sh`

---

## Сборка (§8.5)

### Production (`lib/main.dart`)

```bash
./scripts/build-web.sh
```

Опции:

| Переменная | Описание |
|------------|----------|
| `WEB_BASE_HREF` | `--base-href` для деплоя в подкаталог |
| `SKIP_TDWEB_CHECK=1` | Сборка без `web/tdweb/` (UI без TDLib) |

Результат: `build/web/`

### PoC UI (без Telegram)

```bash
./scripts/build-web-poc.sh
```

---

## Локальный просмотр

```bash
./scripts/build-web.sh
cd build/web && python3 -m http.server 8765
# http://127.0.0.1:8765
```

---

## Деплой на EU backend

После [§8.4 bootstrap](WEB_INFRA.md):

```bash
# На EU VPS (из checkout RioGram)
sudo ./scripts/deploy-web-eu.sh

# Проверка через aggregator
./scripts/verify-web-deploy.sh
curl -s http://127.0.0.1:8080/ | head
```

Скрипт:
1. `./scripts/build-web.sh`
2. Копирует `build/web/` → `/opt/riogram/web/`
3. EU nginx (`riogram-eu-backend`) отдаёт static через `try_files`

### Обновление без пересборки на сервере

```bash
# Локально
./scripts/build-web.sh
rsync -avz build/web/ user@eu-vps:/opt/riogram/web/
```

---

## Проверка end-to-end

1. EU: `./scripts/verify-web-deploy.sh`
2. RU: `./scripts/verify-web-tunnel.sh`
3. Снаружи: `curl -s https://your-domain.ru[:PORT]/ | grep flutter` (порт из `RIOGRAM_HTTPS_PORT`)
4. Браузер: DevTools → Network → документ `index.html`, `main.dart.js`
5. WSS: в настройках указать `wss://your-domain.ru[:PORT]` → WS на `…/venus.web.telegram.org/apiws`

---

## CI

GitHub Actions job **`Flutter build (Web)`**:
- `flutter build web --release --no-wasm-dry-run`
- Артефакт `riogram-web` (`build/web/`, 7 дней)

Локально те же проверки:

```bash
./scripts/ci-flutter.sh
./scripts/build-web.sh
```

---

## `web/index.html`

Уже настроено для production:

- `<base href="/">` — заменяется Flutter при `--base-href`
- Meta: `mobile-web-app-capable`, `apple-mobile-web-app-title`
- Transport scripts **до** Flutter:
  1. `js/wss_proxy_hook.js`
  2. `tdweb/tdweb.js`
  3. `js/tdlib_bridge.js`
- Service worker: генерируется Flutter (`flutter_service_worker.js`)

---

## Troubleshooting

| Проблема | Решение |
|----------|---------|
| Белый экран | DevTools Console; проверить `main.dart.js` 200 |
| TDLib не инициализируется | `web/tdweb/tdweb.js` в bundle; `./scripts/copy-tdweb.sh` |
| 404 на assets | `WEB_BASE_HREF` должен совпадать с URL path |
| 502 на `/` | EU nginx + `/opt/riogram/web/index.html` |
| WSS не работает | §8.2 настройки + §8.3 proxy + §8.4 tunnel |

---

## E2E (§8.6)

```bash
./scripts/run-web-e2e.sh
```

См. [WEB_E2E.md](WEB_E2E.md) — автоматизация + ручные чеклисты (auth, RU, tunnel).
