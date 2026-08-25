# Настройка прокси RioGram

RioGram рассчитан на **Fake TLS MTProto-прокси с DPI-патчами в TDLib**. Официальный Telegram Desktop не использует те же патчи ClientHello/DRS и **не подходит** для проверки этой связки.

## Архитектура

```
RioGram (Flutter + TDLib с DPI-патчами)
    ↓ Fake TLS ClientHello (ee-секрет) + obfuscated2
PhantomProxy Front (RU VPS :15443)          StealthGate Front (RU VPS :14443, резерв)
    ↓ PHRP-туннель (AES-GCM)                      ↓ SGFB-туннель
PhantomProxy Back  (EU VPS :15443)          StealthGate Back  (EU VPS :14443)
    ↓ obfuscated2 → Telegram DC                     ↓ MTProto → Telegram DC
149.154.x.x:443
```

Клиент **всегда** подключается к RU edge. EU relay не должен быть публичным.

## Прокси-серверы

| Прокси | Роль | Репозиторий |
|--------|------|-------------|
| **PhantomProxy** | Основной MTProto-прокси (Go), relay front/back | [RioTwWks/PhantomProxy](https://github.com/RioTwWks/PhantomProxy) |
| **StealthGate** | Резервный, Front/Back split (Rust), протокол SGFB | [RioTwWks/StealthGate](https://github.com/RioTwWks/StealthGate) |

## Протоколы relay (RU → EU)

### PhantomProxy — PHRP

Front завершает Fake TLS + obfuscated2 с клиентом, затем открывает туннель на back:

```
MAGIC "PHRP" | nonce(16) | HMAC-SHA256(psk, nonce)(32) | dcID(2) | client_ip(4) | client_port(2)
→ AES-GCM фреймы с MTProto-трафиком
```

На RU в логах: `backend=relay-front peer=<EU>:15443`.  
На EU: `relay back подключён ... backend=<DC или middle-proxy>`.

Согласовать на front и back: `relay.mode`, `relay.peer_addr`, `relay.psk`.

### StealthGate — SGFB

Front отправляет opening-кадр на back после детекции MTProto:

```
MAGIC "SGFB" | VERSION | SHA256(auth_token) | secret_mode | backend | initial_data
→ ACK (1 байт) → bidirectional relay (опционально ChaCha20 при encrypt_relay=true)
```

Согласовать на front и back: `split.auth_token`, `split.encrypt_relay`, `split.back_servers` / `front_allowlist`.

Подробнее: [StealthGate SPLIT.md](https://github.com/RioTwWks/StealthGate/blob/main/docs/SPLIT.md).

### Системный HTTP/SOCKS-прокси

Если в ОС настроен прокси (корпоративная сеть, VPN), RioGram определяет его автоматически:

1. **Linux (GProxyResolver)** — `GProxyResolver` через native plugin (GNOME, KDE, NetworkManager)
2. **Переменные окружения** — `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY` (Linux/Windows/macOS)
3. **`/etc/environment`** — systemd/login-сессии без экспорта в shell
4. **GNOME** — `gsettings org.gnome.system.proxy` (fallback)
5. **KDE** — `kreadconfig5 kioslaverc` (fallback)
6. **Android** — `http.proxyHost` / `http_proxy` (Wi‑Fi proxy)

Поведение:

| Сценарий | Что происходит |
|----------|----------------|
| Только системный прокси | TDLib подключается к Telegram через HTTP CONNECT / SOCKS5 |
| Системный + PhantomProxy/StealthGate | Системный прокси — **транспорт** до VPS; MTProto Fake TLS — поверх туннеля |
| Только MTProto в `.env` | Как раньше, прямое подключение к RU edge |

Транспортный прокси регистрируется с comment `RioGram:Transport` (см. патч TDLib `ConnectionCreator`).

---

## Handshake клиента (что ожидают прокси)

```
1. TCP connect
2. Fake TLS ClientHello  — ee + 16-байт ключ + домен (SNI), HMAC в ClientRandom
3. Fake TLS ServerHello  — синтетический ответ прокси
4. obfuscated2 (64 байта) — внутри TLS Application Data
5. MTProto               — дальше в TLS-записях с DRS
```

Референсная реализация клиента: `internal/testclient` и `internal/faketls/client.go` в PhantomProxy (utls Chrome, один TCP-сегмент для ClientHello).

## Конфигурация в `.env`

```env
# PhantomProxy Front (RU) — основной, приоритет 1
PROXY_PHANTOM_HOST=37.9.4.136
PROXY_PHANTOM_PORT=15443
PROXY_PHANTOM_SECRET=ee40197aeb7c14b99661503f76fce2ca67626f6c2e636f6d

# StealthGate Front (RU) — резервный, приоритет 2
#PROXY_STEALTH_HOST=37.9.4.136
#PROXY_STEALTH_PORT=14443
#PROXY_STEALTH_SECRET=ee0123456789abcdef0123456789abcdef7777772e636c6f7564666c6172652e636f6d
```

Формат секрета: `ee` + 16 байт ключа (hex) + домен маскировки (hex ASCII).  
Пример: `...67626f6c2e636f6d` → SNI `bol.com`.

## Режим совместимости TDLib

В `td/td/mtproto/dpi_bypass/DpiBypass.h`:

```cpp
constexpr bool kDpiBypassStableProxyMode = true;  // профиль по SNI-домену, без фрагментации
```

- `true` (по умолчанию) — стабильный handshake с PhantomProxy/StealthGate: профиль ClientHello выбирается по домену из ee-секрета (Yandex / VK / Госуслуги / Chrome для прочих), **без ECH** и фрагментации.
- `false` — полный DPI bypass: ротация профилей + фрагментация ClientHello + DRS.

Подробнее о профилях маскировки и Probe Resistance: [STEALTH.md](STEALTH.md).

> **Важно:** PhantomProxy с политикой `reject_fronting` отклоняет ClientHello с ECH (расширение `0xfe0d`).
> Профили Yandex, VK и Gosuslugi не содержат ECH и подходят для stable mode.

После смены флага пересобрать TDLib:

```bash
./scripts/build-tdlib.sh
./scripts/copy-tdlib.sh linux
```

## Логика failover в клиенте

Реализовано в `ProxyManager` через API TDLib:

1. `addProxy` — регистрация PhantomProxy и StealthGate
2. `pingProxy` — проверка с таймаутом 5 секунд
3. `enableProxy` — активация первого доступного
4. Каждые 30 секунд — health-check активного прокси
5. При `connectionStateWaitingForNetwork` — переключение на следующий

### Настройки в приложении

- **Автоматическое переключение** — вкл/выкл failover (SharedPreferences)
- **Тест** — ручная проверка конкретного прокси
- **Включить** — ручной выбор активного прокси

## Деплой прокси на VPS

### PhantomProxy (relay)

| Сервер | Роль | systemd |
|--------|------|---------|
| RU | front (`relay.mode: front`) | `phantom-proxy` |
| EU | back (`relay.mode: back`) | `phantom-proxy` |

```bash
# RU
sudo systemctl status phantom-proxy
journalctl -u phantom-proxy -f

# EU — проверка выхода к Telegram DC
nc -vz -w 5 149.154.167.99 443
```

### StealthGate (SGFB split)

| Сервер | Роль | install |
|--------|------|---------|
| RU | front | `sudo bash deploy/install.sh --front` |
| EU | back | `sudo bash deploy/install.sh --back` |

```bash
sudo systemctl status stealth-gate
just test-split   # из репозитория StealthGate
```

## Проверка до запуска RioGram

### 1. TCP и TLS с клиентской машины

```bash
./scripts/verify-proxy.sh
```

Или вручную:

```bash
nc -vz 37.9.4.136 15443
openssl s_client -connect 37.9.4.136:15443 -servername bol.com -brief </dev/null
```

### 2. PhantomProxy testclient (без RioGram)

Из репозитория [PhantomProxy](https://github.com/RioTwWks/PhantomProxy):

```bash
go test -tags=integration ./internal/proxy/...
```

Или поднять mock DC и прогнать `internal/testclient` против RU front с тем же `ee`-секретом.

### 3. Логи прокси — что искать

| Лог | Значение |
|-----|----------|
| `клиент подключён ... relay-front` | Fake TLS + obfuscated2 на RU успешны |
| `relay back ... upload>0 download>0` | MTProto прошёл до Telegram DC |
| `upload=0 download=0` | Handshake OK, но MTProto-данных не было |
| `fake TLS отклонён` | секрет, HMAC, replay, JA3 или timestamp |
| StealthGate `c2b=0 b2c=0` | SGFB открыт, relay без данных |

### 4. Типичные проблемы

- **Секрет без домена** → TDLib: `Unsupported proxy secret`
- **Разный `relay.psk` / `auth_token`** на front и back → relay отклонён
- **Middle proxy на EU back** без публичного IPv4 → сессии 0/0; попробовать direct DC
- **Anti-replay** при частых reconnect — подождать или перезапустить прокси
- **`kDpiBypassStableProxyMode = false`** — нестабильный handshake с прокси

## Связанные документы

- [Патчи TDLib](TDLIB_PATCHES.md)
- [Быстрый старт](QUICKSTART.md)
