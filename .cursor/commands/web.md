---
command: RioGram Web — оглавление §8 (PoC → E2E)
---

# RioGram Web (§8)

Браузерный клиент с обходом блокировок через WSS reverse proxy RU→EU→Telegram + tdweb WASM.

## Документация

| § | Файл | Содержание |
|---|------|------------|
| 8.1 | [docs/WEB_POC.md](../../docs/WEB_POC.md) | PoC, выбор стратегии |
| 8.2 | [docs/WEB_TRANSPORT.md](../../docs/WEB_TRANSPORT.md) | WSS hook, tdweb, Dart bridge |
| 8.3 | [docs/WEB_PROXY.md](../../docs/WEB_PROXY.md) | `riogram-wss-proxy` |
| 8.4 | [docs/WEB_INFRA.md](../../docs/WEB_INFRA.md) | SSH tunnel, Nginx RU/EU, UFW |
| 8.5 | [docs/WEB.md](../../docs/WEB.md) | Flutter build + деплой |
| 8.6 | [docs/WEB_E2E.md](../../docs/WEB_E2E.md) | E2E + ручные чеклисты |

## Команды Cursor

| Команда | Когда использовать |
|---------|-------------------|
| [@deploy-web-proxy](deploy-web-proxy.md) | §8.3 — WSS reverse proxy на EU |
| [@deploy-web-infra](deploy-web-infra.md) | §8.4 — RU frontend + EU backend |
| [@deploy-web-app](deploy-web-app.md) | §8.5 — сборка и деплой Flutter Web |
| [@e2e-web](e2e-web.md) | §8.6 — автоматический и ручной E2E |

## Быстрые команды

```bash
# Сборка (tdweb + Flutter)
./scripts/build-tdweb.sh && ./scripts/copy-tdweb.sh
./scripts/build-web.sh

# Локальный E2E stack
./scripts/run-web-e2e.sh

# CI-эквивалент Web jobs
./scripts/build-web.sh
WSS_STABILITY_SECONDS=30 ./scripts/run-web-e2e.sh
```

## Порты (production)

| Где | Порт | Сервис |
|-----|------|--------|
| EU | `127.0.0.1:5001` | `riogram-wss-proxy` |
| EU | `127.0.0.1:8080` | nginx aggregator (static + WSS) |
| EU | `/opt/riogram/web` | Flutter static |
| RU | `127.0.0.1:8080` | SSH tunnel → EU `:8080` |
| RU | `:443` | Nginx TLS → tunnel |
