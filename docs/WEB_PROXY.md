# Web-прокси RioGram (§8.3)

Серверная часть WSS reverse proxy для браузерного клиента RioGram.

См. также: [WEB_TRANSPORT.md](WEB_TRANSPORT.md) (§8.2 клиент), [WEB_POC.md](WEB_POC.md) (выбор **Варианта A**), [PROXY.md](PROXY.md) (native MTProto).

---

## Архитектура

```
┌─────────────┐   WSS/443    ┌──────────────┐  SSH -R   ┌─────────────────────────┐
│   Browser   │ ──────────► │  RU VPS      │ ────────► │  EU VPS (127.0.0.1)     │
│ Flutter Web │  your.ru    │  Nginx+LE    │  tunnel   │  riogram-wss-proxy:5001 │
└─────────────┘             └──────────────┘           └───────────┬─────────────┘
                                                                   │ WSS
                                                                   ▼
                                                    venus/pluto.web.telegram.org/apiws
```

### Почему Вариант A

| Вариант | Для Web | Решение |
|---------|---------|---------|
| **A. WSS reverse proxy** | ✅ | **Выбрано** — прозрачный bridge browser ↔ Telegram |
| B. StealthGate/PhantomProxy | ❌ | Fake TLS MTProto, не browser WebSocket |
| C. tg-ws-proxy на сервере | ❌ | SOCKS5 для Desktop, не `wss://…/apiws` |

Реализация: **`bin/riogram-wss-proxy`** (Go), алгоритм совместим с [TG-WS-API](https://github.com/CloudflareHackers/TG-WS-API) и RioGram URL rewrite.

---

## URL и маршрутизация

Клиент переписывает URL (§8.2):

```
wss://venus.web.telegram.org/apiws
  → wss://your-domain.ru/venus.web.telegram.org/apiws
```

Прокси парсит path:

| Path | Upstream |
|------|----------|
| `/venus.web.telegram.org/apiws` | `wss://venus.web.telegram.org/apiws` |
| `/pluto.web.telegram.org` | `wss://pluto.web.telegram.org/apiws` (default path) |
| `/evil.example.com/apiws` | **403 Forbidden** |

Allowlist: `*.web.telegram.org`, `*.telegram.org` (regex как в TG-WS-API).

---

## Сборка

```bash
./scripts/build-wss-proxy.sh
# → bin/riogram-wss-proxy
```

Зависимости: Go 1.22+.

---

## Конфигурация (EU backend)

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `WSS_PROXY_LISTEN` | `127.0.0.1:5001` | **Только localhost** — доступ через SSH-туннель (§8.4) |
| `WSS_PROXY_TOKEN` | _(пусто)_ | Опциональная авторизация (`Authorization: Bearer …`) |
| `WSS_PROXY_UPSTREAM_ORIGIN` | _(пусто)_ | Override `Origin` к Telegram (обычно не нужен) |

### Запуск вручную

```bash
export WSS_PROXY_LISTEN=127.0.0.1:5001
./bin/riogram-wss-proxy
```

### systemd

```bash
sudo useradd --system --no-create-home riogram 2>/dev/null || true
sudo install -m 755 bin/riogram-wss-proxy /opt/riogram/bin/
sudo cp deploy/systemd/riogram-wss-proxy.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now riogram-wss-proxy
journalctl -u riogram-wss-proxy -f
```

---

## Локальная проверка (до деплоя)

```bash
# unit-тесты Go
cd server/wss-proxy && go test ./...

# smoke: health + 403 на чужой host
./scripts/test-wss-proxy.sh

# опционально: WebSocket через прокси к Telegram
pip install websockets  # если нужно
WSS_PROXY_TEST_UPSTREAM=1 ./scripts/test-wss-proxy.sh
```

### wscat (ручная проверка)

```bash
WSS_PROXY_LISTEN=127.0.0.1:5001 ./bin/riogram-wss-proxy &
curl -s http://127.0.0.1:5001/health | jq .

# через npm wscat:
npx wscat -c ws://127.0.0.1:5001/venus.web.telegram.org/apiws -s binary
```

---

## Nginx на RU VPS (preview §8.4)

Пример фрагмента для проксирования WSS через SSH-туннель (`127.0.0.1:8080` → EU `5001`):

```nginx
location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 86400;
}
```

Полная инфраструктура (autossh, Let's Encrypt, UFW) — §8.4 в [TODO.md](../TODO.md).

---

## Безопасность

1. **Слушать только `127.0.0.1`** на EU — порт не открывать в UFW наружу.
2. **Allowlist Telegram host** — произвольные upstream запрещены.
3. **Опциональный token** — если RU Nginx не фильтрует злоупотребления.
4. **Нет хранения данных** — pure pass-through relay.

---

## Отличия от native PROXY.md

| | Native PhantomProxy | Web riogram-wss-proxy |
|---|---------------------|------------------------|
| Протокол | Fake TLS MTProto | Browser WSS |
| Клиент | RioGram desktop/mobile | RioGram Web + tdweb |
| Edge | RU VPS :15443 | RU Nginx :443 WSS |
| Backend | EU PhantomProxy back | EU localhost :5001 |

---

## Troubleshooting

| Симптом | Проверка |
|---------|----------|
| `403 Forbidden` | Path не содержит `*.web.telegram.org` |
| `502 upstream error` | EU → Telegram сеть; `curl -I https://venus.web.telegram.org` |
| WS сразу закрывается | Nginx: `proxy_http_version 1.1`, `Upgrade`, `Connection` |
| Клиент не использует прокси | Настройки WSS в UI; `localStorage` → `riogram_wss_proxy_config` |

---

## Следующие шаги

- **§8.4** — SSH reverse tunnel RU↔EU + Nginx + Let's Encrypt
- **§8.6** — E2E авторизация через WSS из браузера в РФ
