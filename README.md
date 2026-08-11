# RioGram — клиент Telegram, устойчивый к блокировкам

![CI](https://github.com/RioTwWks/RioGram/actions/workflows/ci.yml/badge.svg)

**RioGram** — кросс-платформенный клиент Telegram на Flutter с модифицированным TDLib. Проект создан для работы в условиях агрессивного DPI (ТСПУ) в РФ.

## Возможности

- **Рандомизация TLS ClientHello** — маскировка под Chrome, Firefox, Yandex, Safari
- **Фрагментация** первого пакета рукопожатия
- **DRS** — динамические размеры TLS-записей
- **Автоматический failover** между PhantomProxy и StealthGate
- **Экран настроек прокси** с ручным тестом и переключением

Поддерживаемые платформы: Windows, macOS, Linux, Android, iOS.

## Этапы MVP

Flutter + TDLib + авторизация
DPI-патчи в TDLib
Прокси и failover
UI, чаты, темы, уведомления
Сборка на всех платформах (CI + Release + docs)
GitHub Actions: Flutter + TDLib Linux
Пакеты для Linux, Windows, macOS, Android, iOS

## Быстрый старт

```bash
cp .env.example .env
# Заполните TELEGRAM_API_ID, TELEGRAM_API_HASH и адреса прокси
# Или: export TELEGRAM_API_ID=... && ./scripts/generate-env.sh

flutter pub get
./scripts/build-tdlib.sh   # сборка libtdjson
flutter run -d linux
```

Подробнее: [docs/QUICKSTART.md](docs/QUICKSTART.md)

## Документация

- [Быстрый старт](docs/QUICKSTART.md)
- [Настройка прокси](docs/PROXY.md)
- [Патчи TDLib (DPI)](docs/TDLIB_PATCHES.md)
- [CI/CD и релизы](docs/CI.md)
- [Секреты для GitHub Actions](docs/SECRETS.md)
- [Сборка на всех платформах](docs/BUILD.md)
- [Установка из релиза](docs/INSTALL.md)
- [План разработки](PLAN.md)
- [Список задач](TODO.md)

## Структура проекта

```
lib/
├── core/
│   ├── config/       # AppConfig из .env
│   ├── tdlib/        # FFI-обёртка libtdjson
│   ├── auth/         # Авторизация
│   └── proxy/        # ProxyManager, failover
├── screens/
│   ├── auth/         # Вход
│   ├── chats/        # Список чатов
│   └── settings/     # Настройки прокси
└── widgets/
td/                   # Модифицированный TDLib
scripts/              # Сборка TDLib
docs/                 # Документация (RU)
```

## Лицензия

GPLv3 with OpenSSL exception.
