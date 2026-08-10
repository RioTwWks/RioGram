# RioGram — клиент Telegram, устойчивый к блокировкам

**RioGram** — кросс-платформенный клиент Telegram на Flutter с модифицированным TDLib. Проект создан для работы в условиях агрессивного DPI (ТСПУ) в РФ.

## Возможности

- **Рандомизация TLS ClientHello** — маскировка под Chrome, Firefox, Yandex, Safari
- **Фрагментация** первого пакета рукопожатия
- **DRS** — динамические размеры TLS-записей
- **Автоматический failover** между PhantomProxy и StealthGate
- **Экран настроек прокси** с ручным тестом и переключением

Поддерживаемые платформы: Windows, macOS, Linux, Android, iOS.

## Статус MVP

| Этап | Статус | Описание |
|------|--------|----------|
| 1 | ✅ | Flutter + TDLib + авторизация |
| 2 | ✅ | DPI-патчи в TDLib |
| 3 | ✅ | Прокси и failover |
| 4 | ⏳ | Полировка UI и чаты |
| 5 | ⏳ | Сборка на всех платформах |

## Быстрый старт

```bash
cp .env.example .env
# Заполните TELEGRAM_API_ID, TELEGRAM_API_HASH и адреса прокси

flutter pub get
./scripts/build-tdlib.sh   # сборка libtdjson
flutter run -d linux
```

Подробнее: [docs/QUICKSTART.md](docs/QUICKSTART.md)

## Документация

- [Быстрый старт](docs/QUICKSTART.md)
- [Настройка прокси](docs/PROXY.md)
- [Патчи TDLib (DPI)](docs/TDLIB_PATCHES.md)
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
