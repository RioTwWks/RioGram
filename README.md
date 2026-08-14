# RioGram — клиент Telegram, устойчивый к блокировкам

![CI](https://github.com/RioTwWks/RioGram/actions/workflows/ci.yml/badge.svg)

**RioGram** — кросс-платформенный клиент Telegram на Flutter с модифицированным TDLib. Проект создан для работы в условиях агрессивного DPI (ТСПУ) в РФ.

## Возможности

### Обход блокировок
- **Рандомизация TLS ClientHello** — маскировка под Chrome, Firefox, Yandex, Safari
- **Фрагментация** первого пакета рукопожатия
- **DRS** — динамические размеры TLS-записей
- **Автоматический failover** между PhantomProxy и StealthGate
- **Экран настроек прокси** с ручным тестом и переключением

### Клиент Telegram (MVP + §6.2)
- Авторизация по номеру, 2FA, список чатов, текст/фото/файлы
- **Список чатов:** pin, архив, папки, mute, черновики, типы чатов
- **Поиск** по чатам и сообщениям, удаление/очистка, «непрочитанное»
- **Desktop:** master-detail (≥720px), три колонки (≥840px), горячие клавиши

Поддерживаемые платформы: Windows, macOS, Linux, Android, iOS.

## Этапы MVP

Flutter + TDLib + авторизация ✅  
DPI-патчи в TDLib ✅  
Прокси и failover ✅  
UI, чаты, темы, уведомления ✅  
§6.2 Список чатов и организация ✅  
Сборка на всех платформах (CI + Release + docs) ✅  

Дальнейший паритет с Telegram — [TODO.md](TODO.md) §6.3+.

## Быстрый старт

```bash
cp .env.example .env
# Заполните TELEGRAM_API_ID, TELEGRAM_API_HASH и адреса прокси
# Или: export TELEGRAM_API_ID=... && ./scripts/generate-env.sh

flutter pub get
./scripts/build-tdlib.sh        # сборка libtdjson
./scripts/copy-tdlib.sh linux   # копирование в проект (нужно один раз после сборки TDLib)
flutter run -d linux
```

Подробнее: [docs/QUICKSTART.md](docs/QUICKSTART.md)

## Документация

- [Быстрый старт](docs/QUICKSTART.md)
- [Список чатов (§6.2)](docs/CHATS.md)
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
│   ├── auth/         # AuthManager
│   ├── chat/         # ChatManager, TdlibChatParser
│   ├── proxy/        # ProxyManager, failover
│   ├── theme/        # ThemeManager
│   └── notifications/
├── screens/
│   ├── auth/         # Вход
│   ├── chats/        # ChatsScreen (адаптивный layout)
│   ├── chat/         # Переписка
│   └── settings/     # Настройки прокси и темы
├── widgets/          # ChatListTile, ChatFolderSidebar, …
└── models/           # chat_models, auth_models, proxy_models
td/                   # Модифицированный TDLib
scripts/              # Сборка TDLib
docs/                 # Документация (RU)
.cursor/              # Правила и команды Cursor
```

## Лицензия

GPLv3 with OpenSSL exception.
