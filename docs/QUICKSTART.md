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
PROXY_PHANTOM_PORT=443
PROXY_PHANTOM_SECRET=dd...

PROXY_STEALTH_HOST=185.x.x.x
PROXY_STEALTH_PORT=443
PROXY_STEALTH_SECRET=dd...
```

## 3. Сборка TDLib

```bash
./scripts/build-tdlib.sh
./scripts/copy-tdlib.sh linux   # или windows / macos / android
```

Подробнее по всем платформам: [docs/BUILD.md](docs/BUILD.md)

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

## Устранение неполадок

| Проблема | Решение |
|----------|---------|
| `libtdjson не найден` | Соберите TDLib и скопируйте библиотеку |
| `api_id/api_hash` | Заполните `.env` |
| Прокси недоступен | Проверьте VPS, секрет, порт 443 |
| Все прокси красные | Проверьте StealthGate Front/Back связку |
