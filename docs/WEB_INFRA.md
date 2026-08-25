# RioGram Web — инфраструктура RU Frontend + EU Backend (§8.4)

Документ описывает деплой SSH reverse tunnel, Nginx WSS и firewall для браузерного RioGram.

См. также: [WEB_PROXY.md](WEB_PROXY.md) (§8.3 WSS proxy), [WEB_TRANSPORT.md](WEB_TRANSPORT.md) (§8.2 клиент), [PROXY.md](PROXY.md) (native MTProto).

---

## Архитектура

```
┌─────────────┐  HTTPS/WSS   ┌──────────────────┐   SSH -R    ┌────────────────────────────┐
│   Browser   │ ───────────► │  RU VPS          │ ──────────► │  EU VPS (127.0.0.1 only)   │
│  RioGram Web│  domain.ru   │  Nginx :443      │  :8080      │  nginx :8080 (aggregator)  │
└─────────────┘              │  LE certificate  │             │    ├─ :5001 wss-proxy      │
                             └──────────────────┘             │    └─ :5000 static web      │
                                                              └─────────────┬──────────────┘
                                                                            │ WSS
                                                                            ▼
                                                             venus/pluto.web.telegram.org
```

### Порты (согласованная схема)

| Где | Порт | Сервис |
|-----|------|--------|
| EU | `127.0.0.1:5001` | `riogram-wss-proxy` (§8.3) |
| EU | `127.0.0.1:8080` | `riogram-eu-backend` nginx — static + WSS |
| EU | `/opt/riogram/web` | Flutter Web static (§8.5) |
| RU | `127.0.0.1:8080` | SSH reverse tunnel → EU `:8080` |
| RU | `:443` | Nginx TLS → `127.0.0.1:8080` |

---

## Быстрый старт

### 1. EU backend

```bash
# На EU VPS
git clone ... && cd RioGram
./scripts/build-wss-proxy.sh
sudo ./scripts/setup-web-infra-eu.sh

sudo nano /etc/riogram/web.env   # TUNNEL_RU_HOST, TUNNEL_SSH_USER, ...
sudo ssh-keygen -t ed25519 -f /var/lib/riogram/.ssh/id_ed25519 -N ''
sudo cat /var/lib/riogram/.ssh/id_ed25519.pub   # → добавить на RU

sudo systemctl start riogram-wss-proxy riogram-eu-backend riogram-static-placeholder
sudo systemctl start autossh-riogram-tunnel
sudo ./deploy/ufw/riogram-eu.sh
```

### 2. RU frontend

```bash
# На RU VPS
sudo RIOGRAM_DOMAIN=your-domain.ru ./scripts/setup-web-infra-ru.sh

# authorized_keys для user tunnel
sudo nano /var/lib/riogram-tunnel/.ssh/authorized_keys

# DNS + SSL
sudo certbot --nginx -d your-domain.ru
sudo ./deploy/ufw/riogram-ru.sh
```

### 3. Проверка туннеля (RU VPS)

```bash
./scripts/verify-web-tunnel.sh
curl -s http://127.0.0.1:8080/health | jq .
```

### 4. Проверка снаружи

```bash
curl -s https://your-domain.ru/health | jq .
# WSS (после включения прокси в клиенте):
# wss://your-domain.ru/venus.web.telegram.org/apiws
```

---

## Конфигурация

Шаблон: [deploy/env/riogram-web.env.example](../deploy/env/riogram-web.env.example)

| Переменная | Описание |
|------------|----------|
| `RIOGRAM_DOMAIN` | Домен RU frontend |
| `TUNNEL_SSH_USER` | SSH-пользователь на RU (рекомендуется `tunnel`) |
| `TUNNEL_RU_HOST` | IP RU VPS |
| `TUNNEL_RU_PORT` | Порт на RU localhost (8080) |
| `TUNNEL_EU_PORT` | Порт EU backend aggregator (8080) |
| `TUNNEL_RU_BIND` | `127.0.0.1` — туннель только на localhost RU |
| `EU_UFW_ALLOW_SSH_FROM` | Ограничить SSH на EU IP RU VPS |

---

## Компоненты репозитория

| Файл | Назначение |
|------|------------|
| `deploy/nginx/riogram-ru.conf.template` | Nginx RU (HTTPS + WSS upgrade) |
| `deploy/nginx/riogram-eu-backend.conf` | Nginx EU aggregator |
| `deploy/systemd/autossh-riogram-tunnel.service` | autossh EU→RU |
| `deploy/systemd/riogram-eu-backend.service` | EU nginx |
| `scripts/autossh-riogram-tunnel.sh` | Wrapper с env |
| `scripts/setup-web-infra-eu.sh` | Bootstrap EU |
| `scripts/setup-web-infra-ru.sh` | Bootstrap RU |
| `scripts/verify-web-tunnel.sh` | Проверка с RU |
| `scripts/test-web-infra-local.sh` | Локальная симуляция EU stack |
| `deploy/ufw/riogram-{ru,eu}.sh` | Firewall |

---

## SSH reverse tunnel

EU инициирует соединение к RU (EU не принимает входящие app-порты):

```bash
autossh -M 0 -N \
  -R 127.0.0.1:8080:127.0.0.1:8080 \
  tunnel@ru_vps_ip
```

На RU в `sshd_config`:

```
GatewayPorts clientspecified
```

См. [deploy/ssh/sshd-gatewayports-snippet.conf](../deploy/ssh/sshd-gatewayports-snippet.conf).

---

## Nginx WSS (RU)

Критичные директивы (уже в шаблоне):

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $connection_upgrade;
proxy_read_timeout 86400s;
proxy_buffering off;
```

---

## Безопасность

1. **EU**: приложения только на `127.0.0.1`; UFW — только SSH (желательно с IP RU).
2. **RU**: UFW — SSH + 80/443; публичная точка входа.
3. **Tunnel user** на RU: без shell, только `authorized_keys` + `AllowTcpForwarding remote`.
4. **Let's Encrypt** на RU — браузер видит валидный HTTPS к `.ru` домену.

---

## Локальная симуляция (dev)

```bash
./scripts/test-web-infra-local.sh
```

Поднимает wss-proxy + static + EU nginx на `127.0.0.1:8080` без SSH.

---

## Troubleshooting (§8.7)

| Симптом | Действие |
|---------|----------|
| **502 Bad Gateway** (RU) | `curl http://127.0.0.1:8080/health` на RU; `systemctl status autossh-riogram-tunnel` на EU |
| **Port 8080 closed** (RU) | Проверить `GatewayPorts`, SSH ключ, `journalctl -u autossh-riogram-tunnel` |
| **WebSocket closes immediately** | Nginx: `Upgrade` + `Connection` + `proxy_http_version 1.1` |
| **WS drops after ~60s** | Увеличить `proxy_read_timeout` (86400 в шаблоне) |
| **Tunnel keeps dying** | autossh `Restart=always`; `ServerAliveInterval=30` |

---

## Следующие шаги

- **§8.5** — деплой Flutter Web — см. [WEB.md](WEB.md)
- **§8.6** — E2E авторизация через WSS из РФ
