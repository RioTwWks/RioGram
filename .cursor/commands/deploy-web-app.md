---
command: Собрать и задеплоить RioGram Web (§8.5)
---

# Деплой Flutter Web

См. [docs/WEB.md](../../docs/WEB.md).

## Локальная сборка

```bash
./scripts/build-tdweb.sh && ./scripts/copy-tdweb.sh   # один раз
./scripts/build-web.sh
```

## EU VPS

```bash
sudo ./scripts/deploy-web-eu.sh
./scripts/verify-web-deploy.sh
```

## Проверка через tunnel (RU)

```bash
./scripts/verify-web-tunnel.sh
curl -s https://your-domain.ru/ | grep flutter
```
