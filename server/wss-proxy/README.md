# riogram-wss-proxy

Self-hosted WSS reverse proxy for RioGram Web (§8.3, **Variant A**).

Bridges browser WebSocket connections to official Telegram endpoints:

```
Browser  wss://your-domain.ru/venus.web.telegram.org/apiws
   → RU Nginx (§8.4)
   → SSH tunnel
   → riogram-wss-proxy (127.0.0.1:5001)
   → wss://venus.web.telegram.org/apiws
```

Compatible with RioGram client URL rewrite (`web/js/wss_proxy_hook.js`, `WssUrlRewriter`).

## Build

```bash
./scripts/build-wss-proxy.sh
```

Binary: `bin/riogram-wss-proxy`

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `WSS_PROXY_LISTEN` | `127.0.0.1:5001` | Bind address (**localhost only** on EU backend) |
| `WSS_PROXY_TOKEN` | _(empty)_ | Optional bearer token (`Authorization: Bearer …` or `X-RioGram-Proxy-Token`) |
| `WSS_PROXY_UPSTREAM_ORIGIN` | _(empty)_ | Override `Origin` header to Telegram (usually not needed) |

## Run

```bash
export WSS_PROXY_LISTEN=127.0.0.1:5001
./bin/riogram-wss-proxy
```

Health check:

```bash
curl http://127.0.0.1:5001/health
```

## systemd

```bash
sudo cp deploy/systemd/riogram-wss-proxy.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now riogram-wss-proxy
```

See [docs/WEB_PROXY.md](../../docs/WEB_PROXY.md) for full deployment.
