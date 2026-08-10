# Настройка прокси RioGram

## Архитектура

```
RioGram (Flutter + TDLib с DPI-патчами)
    ↓ MTProto + Fake TLS
PhantomProxy (RU VPS, основной)
    ↓ failover
StealthGate Front (RU VPS, резервный)
    ↓ SGFB-туннель
StealthGate Back (EU VPS)
    ↓
Telegram DC
```

## Прокси-серверы

| Прокси | Роль | Репозиторий |
|--------|------|-------------|
| **PhantomProxy** | Основной MTProto-прокси (Go) | [RioTwWks/PhantomProxy](https://github.com/RioTwWks/PhantomProxy) |
| **StealthGate** | Резервный, Front/Back Split (Rust) | [RioTwWks/StealthGate](https://github.com/RioTwWks/StealthGate) |

> Не подключайтесь напрямую к EU-серверу. Клиент всегда ходит через RU-посредник.

## Конфигурация в `.env`

```env
# PhantomProxy — основной (приоритет 1)
PROXY_PHANTOM_HOST=178.x.x.x
PROXY_PHANTOM_PORT=443
PROXY_PHANTOM_SECRET=ddxxxxxxxx...

# StealthGate Front — резервный (приоритет 2)
PROXY_STEALTH_HOST=185.x.x.x
PROXY_STEALTH_PORT=443
PROXY_STEALTH_SECRET=ddxxxxxxxx...
```

Секрет (`secret`) — hex-строка Fake TLS из конфига прокси.

## Логика failover в клиенте

Реализовано в `ProxyManager` через API TDLib:

1. `addProxy` — регистрация PhantomProxy и StealthGate
2. `pingProxy` — проверка с таймаутом 5 секунд
3. `enableProxy` — активация первого доступного
4. Каждые 30 секунд — health-check активного прокси
5. При `connectionStateWaitingForNetwork` — переключение на следующий

### Настройки в приложении

- **Автоматическое переключение** — вкл/выкл failover (сохраняется в SharedPreferences)
- **Тест** — ручная проверка конкретного прокси
- **Включить** — ручной выбор активного прокси

## Деплой прокси на VPS

См. `.cursor/commands/deploy-proxy.md` или:

### PhantomProxy

```bash
# На RU VPS
sudo systemctl start phantomproxy
```

### StealthGate (сплит-режим)

```bash
# Front на RU VPS
stealthgate-front --backend eu.example.com:443

# Back на EU VPS
stealthgate-back
```

## Проверка до запуска клиента

1. Подключитесь через официальный Telegram Desktop с тем же прокси
2. Убедитесь, что соединение стабильно
3. Зафиксируйте IP, порт и secret в `.env`

## Связанные документы

- [Патчи TDLib](TDLIB_PATCHES.md)
- [Быстрый старт](QUICKSTART.md)
