---
command: E2E тестирование RioGram Web (§8.6)
---

# Web E2E

Документация: [docs/WEB_E2E.md](../../docs/WEB_E2E.md)

## Автоматический прогон (local)

```bash
./scripts/run-web-e2e.sh
```

## Production

```bash
./scripts/verify-web-tunnel.sh          # RU VPS
WSS_URL=wss://your-domain.ru/venus.web.telegram.org/apiws \
  ./scripts/e2e-wss-stability.sh
E2E_BASE_URL=https://your-domain.ru ./scripts/e2e-web-ui.sh
```

## Ручные проверки

- Авторизация по телефону — чеклист в `docs/WEB_E2E.md`
- Доступ из РФ без VPN — чеклист в `docs/WEB_E2E.md`
- Tunnel reconnect — `systemctl stop/start autossh-riogram-tunnel`
