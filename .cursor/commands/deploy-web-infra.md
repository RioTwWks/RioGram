---
command: Развернуть инфраструктуру RioGram Web RU+EU (§8.4)
---

# Деплой §8.4 — RU Frontend + EU Backend

Полная документация: [docs/WEB_INFRA.md](../../docs/WEB_INFRA.md)

## EU backend

```bash
./scripts/build-wss-proxy.sh
sudo ./scripts/setup-web-infra-eu.sh
sudo nano /etc/riogram/web.env
sudo ssh-keygen -t ed25519 -f /var/lib/riogram/.ssh/id_ed25519 -N ''
sudo systemctl enable --now riogram-wss-proxy riogram-eu-backend autossh-riogram-tunnel
sudo ./scripts/deploy-web-eu.sh   # Flutter static → /opt/riogram/web
sudo ./deploy/ufw/riogram-eu.sh
```

## RU frontend

```bash
sudo RIOGRAM_DOMAIN=your-domain.ru ./scripts/setup-web-infra-ru.sh
# EU pubkey → /var/lib/riogram-tunnel/.ssh/authorized_keys
sudo certbot --nginx -d your-domain.ru
sudo ./deploy/ufw/riogram-ru.sh
./scripts/verify-web-tunnel.sh
```

## Локальная проверка EU stack

```bash
./scripts/test-web-infra-local.sh
```
