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

## 5. §8.4 — SSH-туннель на RU VPS

```bash
# На EU (autossh → RU):
autossh -M 0 -N -R 8080:127.0.0.1:5001 user@ru_vps
```

Nginx на RU проксирует `wss://your-domain.ru/*` → `127.0.0.1:8080`.
