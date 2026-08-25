# RioGram Web — E2E тестирование (§8.6)

Автоматизированные и ручные проверки браузерного RioGram.

См. также: [WEB.md](WEB.md), [WEB_INFRA.md](WEB_INFRA.md), [WEB_TRANSPORT.md](WEB_TRANSPORT.md).

---

## Матрица тестов

| # | Сценарий | Автоматизация | Команда |
|---|----------|---------------|---------|
| 1 | UI загружается (Flutter shell) | ✅ Playwright | `run-web-e2e.sh` |
| 1b | Экран входа, навигация | ⚠️ Manual | CanvasKit — см. § Auth |
| 2 | WSS hook rewrite URL | ✅ Playwright + unit | `run-web-e2e.sh` |
| 3 | WebSocket через proxy path | ✅ Python ping | `e2e-wss-stability.sh` |
| 4 | WSS стабильность 60+ сек | ✅ | `WSS_STABILITY_SECONDS=65` |
| 5 | Static + health через stack | ✅ | `verify-web-deploy.sh` |
| 6 | SSH tunnel RU↔EU | ⚠️ Manual | см. § Tunnel |
| 7 | Авторизация по телефону | ⚠️ Manual | см. § Auth |
| 8 | Доступ из РФ без VPN | ⚠️ Manual | см. § RU access |

---

## Автоматический прогон (local stack)

Поднимает EU nginx + wss-proxy + Flutter static на `127.0.0.1:8080`:

```bash
# Полный suite (~70s из-за WSS stability)
./scripts/run-web-e2e.sh

# Быстрее (без UI или без WSS)
E2E_SKIP_UI=1 ./scripts/run-web-e2e.sh
E2E_SKIP_WSS=1 ./scripts/run-web-e2e.sh
```

Компоненты:

| Скрипт | Что проверяет |
|--------|----------------|
| `scripts/run-web-e2e.sh` | Оркестратор |
| `scripts/e2e-wss-stability.sh` | WS ping 65s через proxy |
| `scripts/e2e-web-ui.sh` | Playwright smoke |
| `e2e/web/tests/smoke.spec.js` | UI, hook, assets |

Только Playwright (stack уже запущен):

```bash
./scripts/test-web-infra-local.sh &
E2E_BASE_URL=http://127.0.0.1:8080 ./scripts/e2e-web-ui.sh
```

---

## Production / staging E2E

После деплоя §8.4–8.5:

```bash
# EU
./scripts/verify-web-deploy.sh

# RU (на VPS)
./scripts/verify-web-tunnel.sh

# WSS через публичный домен (нужен поднятый stack)
WSS_URL=wss://your-domain.ru/venus.web.telegram.org/apiws \
  WSS_STABILITY_SECONDS=65 \
  ./scripts/e2e-wss-stability.sh

# UI через HTTPS
E2E_BASE_URL=https://your-domain.ru ./scripts/e2e-web-ui.sh
```

---

## § Auth — ручной чеклист

> Требует реальный номер телефона и рабочий tdweb + WSS path.

- [ ] Открыть `https://your-domain.ru` (без VPN на устройстве в РФ)
- [ ] DevTools → Console: нет fatal errors при загрузке
- [ ] Экран **«Вход в RioGram»** виден
- [ ] **Настройки → WSS-прокси**: включить, указать `wss://your-domain.ru`
- [ ] DevTools → Application → Local Storage → `riogram_wss_proxy_config` с `enabled: true`
- [ ] Ввести номер телефона → **Продолжить**
- [ ] DevTools → Network → **WS**: URL содержит `your-domain.ru/...web.telegram.org/apiws`
- [ ] Получить код в Telegram → ввести код → попасть в список чатов
- [ ] Отправить тестовое сообщение себе / в Saved Messages

**Fail signals:**

| Симптом | Проверить |
|---------|-----------|
| «tdweb не загружен» | `/tdweb/tdweb.js` 200, §8.2 build |
| WS к `venus.web.telegram.org` напрямую | WSS hook + настройки прокси |
| WS 502 | tunnel + wss-proxy |
| Authorization timeout | EU→Telegram connectivity |

---

## § WebSocket — DevTools

1. F12 → **Network** → фильтр **WS**
2. Перезагрузить / инициировать вход
3. Ожидание:
   - Status **101 Switching Protocols**
   - URL: `wss://your-domain.ru/venus.web.telegram.org/apiws` (или другой DC)
   - Frames: binary traffic после handshake

---

## § WSS stability (60+ сек)

Автоматически:

```bash
WSS_STABILITY_SECONDS=65 ./scripts/e2e-wss-stability.sh
```

Вручную в DevTools: вкладка WS → смотреть **Time** и отсутствие close code 1006 в течение 60+ секунд при idle.

---

## § Tunnel reconnect — ручной чекlist

На **EU VPS**:

```bash
# Симулировать обрыв tunnel
sudo systemctl stop autossh-riogram-tunnel

# На RU — должно упасть
curl -sf http://127.0.0.1:8080/health || echo "tunnel down OK"

# Восстановить
sudo systemctl start autossh-riogram-tunnel
sleep 5

# На RU — снова OK
./scripts/verify-web-tunnel.sh
```

Проверить `Restart=always` в `autossh-riogram-tunnel.service` после kill autossh процесса.

---

## § RU access — ручной чеклист

- [ ] Устройство в РФ, **VPN/прокси выключены** (системные и браузерные)
- [ ] DNS резолвит `your-domain.ru` на RU VPS
- [ ] `https://your-domain.ru` открывается с валидным LE-сертификатом
- [ ] `curl -I https://your-domain.ru` → HTTP/2 200
- [ ] Приложение загружается без блокировки провайдером

---

## CI

Job **`Web E2E`** в `.github/workflows/ci.yml`:

```bash
./scripts/run-web-e2e.sh
```

---

## Troubleshooting E2E

| Ошибка | Решение |
|--------|---------|
| Playwright timeout on login text | Увеличить timeout; проверить `main.dart.js` |
| WSS ping fail | `journalctl -u riogram-wss-proxy`; nginx error log |
| `websockets` module missing | `pip install websockets` |
| Chromium missing | `cd e2e/web && npx playwright install chromium` |

---

## Следующие шаги

После успешного §8.6 — production monitoring (uptime tunnel, WS error rate).
