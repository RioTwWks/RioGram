# Быстрый старт RioGram

## 1. Требования

- Flutter SDK ≥ 3.22
- CMake, Ninja, GCC/Clang, OpenSSL, zlib (для TDLib)
- API-ключи Telegram: [my.telegram.org/apps](https://my.telegram.org/apps)
- VPS с PhantomProxy и StealthGate (см. [PROXY.md](PROXY.md))

## 2. Настройка окружения

```bash
cp .env.example .env
```

Заполните `.env`:

```env
TELEGRAM_API_ID=12345678
TELEGRAM_API_HASH=your_hash

PROXY_PHANTOM_HOST=178.x.x.x
PROXY_PHANTOM_PORT=15443
PROXY_PHANTOM_SECRET=dd...

PROXY_STEALTH_HOST=185.x.x.x
PROXY_STEALTH_PORT=14443
PROXY_STEALTH_SECRET=dd...
```

## 3. Сборка TDLib

```bash
CC=gcc CXX=g++ ./scripts/build-tdlib.sh   # LTO=OFF, JOBS по RAM
./scripts/copy-tdlib.sh linux             # или windows / macos / android
```

> Если ПК зависает на ~90%: `JOBS=1 TD_ENABLE_LTO=OFF ./scripts/build-tdlib.sh` — см. [BUILD.md](BUILD.md).

Подробнее по всем платформам: [docs/BUILD.md](BUILD.md)

Проверка новой версии upstream TDLib (§7.7):

```bash
./scripts/check-tdlib-upstream.sh
```

См. [TDLIB_UPSTREAM_SYNC.md](TDLIB_UPSTREAM_SYNC.md).

Универсальная релизная сборка:

```bash
./scripts/build-release.sh
```

## 4. Запуск приложения

```bash
flutter pub get
flutter run -d linux    # windows / macos / android
```

## 5. Проверка прокси

1. Авторизуйтесь в приложении
2. Откройте **Настройки** (иконка шестерёнки)
3. Нажмите **Тест** у каждого прокси
4. Убедитесь, что индикатор зелёный

## 6. Список чатов (desktop)

На Linux/Windows/macOS с шириной окна **≥840px** — три колонки (папки | чаты | переписка).

**Горячие клавиши:** `Ctrl+F` / `Ctrl+K` — поиск, `Ctrl+N` — новый чат, `Ctrl+↑/↓` — навигация.

Подробнее: [CHATS.md](CHATS.md)

## 7. RioGram Web (браузер)

Сборка и локальный просмотр:

```bash
./scripts/build-tdweb.sh && ./scripts/copy-tdweb.sh   # один раз
./scripts/build-web.sh
cd build/web && python3 -m http.server 8080
```

E2E (локальный stack):

```bash
./scripts/run-web-e2e.sh
```

Production-деплой: RU frontend + EU backend — см. [WEB.md](WEB.md), [WEB_INFRA.md](WEB_INFRA.md).

## Устранение неполадок

| Проблема | Решение |
|----------|---------|
| `libtdjson не найден` | Соберите TDLib и скопируйте библиотеку |
| `api_id/api_hash` | Заполните `.env` |
| Прокси недоступен | `./scripts/verify-proxy.sh`, порт 15443/14443, секрет с доменом |
| Все прокси красные | Проверьте StealthGate Front/Back связку |
| Web: `tdweb` не найден | `./scripts/build-tdweb.sh && ./scripts/copy-tdweb.sh` |
| Web: 502 Bad Gateway | `./scripts/verify-web-tunnel.sh`, см. [WEB_INFRA.md](WEB_INFRA.md) |
