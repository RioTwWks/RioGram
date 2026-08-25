---
command: Развернуть WSS reverse proxy для RioGram Web (§8.3)
---

# Деплой WSS-прокси (EU backend)

См. [docs/WEB_PROXY.md](../../docs/WEB_PROXY.md).

## 1. Сборка

```bash
./scripts/build-wss-proxy.sh
```

## 2. EU VPS — установка

```bash
sudo useradd --system --no-create-home riogram 2>/dev/null || true
sudo mkdir -p /opt/riogram/bin
sudo install -m 755 bin/riogram-wss-proxy /opt/riogram/bin/
sudo cp deploy/systemd/riogram-wss-proxy.service /etc/systemd/system/
```

## 3. Конфигурация

```bash
# /etc/systemd/system/riogram-wss-proxy.service.d/override.conf
[Service]
Environment=WSS_PROXY_LISTEN=127.0.0.1:5001
# Environment=WSS_PROXY_TOKEN=your-secret
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now riogram-wss-proxy
curl http://127.0.0.1:5001/health
```

## 4. Проверка

```bash
./scripts/test-wss-proxy.sh
```

## 5. §8.4 — SSH-туннель (EU → RU)

Туннель пробрасывает **EU nginx aggregator** (`127.0.0.1:8080`), а не wss-proxy напрямую:

```bash
# /etc/riogram/web.env
TUNNEL_RU_PORT=8080
TUNNEL_EU_PORT=8080

sudo systemctl enable --now autossh-riogram-tunnel
```

Nginx на RU: `https://your-domain.ru` → `127.0.0.1:8080` (static + WSS routes).

Полная инфра: [@deploy-web-infra](deploy-web-infra.md) · [docs/WEB_INFRA.md](../../docs/WEB_INFRA.md)
