# RioGram — клиент Telegram, устойчивый к блокировкам

![CI](https://github.com/RioTwWks/RioGram/actions/workflows/ci.yml/badge.svg)

**RioGram** — кросс-платформенный клиент Telegram на Flutter с модифицированным TDLib. Проект создан для работы в условиях агрессивного DPI (ТСПУ) в РФ.

## Возможности

### Обход блокировок
- **Рандомизация TLS ClientHello** — маскировка под Chrome, Firefox, Yandex, Safari, VK, Госуслуги
- **Выбор профиля по SNI-домену** из ee-секрета прокси (российские сервисы)
- **Автосмена TLS-отпечатка** при ошибках handshake и по таймеру (полный режим)
- **Фрагментация** первого пакета рукопожатия
- **DRS** — динамические размеры TLS-записей
- **Автоматический failover** между PhantomProxy и StealthGate
- **Экран настроек прокси** с ручным тестом и переключением

### Клиент Telegram

- Авторизация, 2FA, список чатов, сообщения, медиа, группы, звонки
- **Список чатов (§6.2):** pin, архив, папки, mute, поиск, desktop layout
- **RioGram §7:** призрачный режим, анти-отзыв, Local Premium, AdBlock, Mini Apps, LaTeX, плагины
- **Дизайн §9:** классический вид Telegram (`TelegramTheme`)

Поддерживаемые платформы: Windows, macOS, Linux, Android, iOS, Web (WSS + tdweb).

## Этапы MVP

Flutter + TDLib + авторизация ✅  
DPI-патчи в TDLib ✅  
Прокси и failover ✅  
UI, чаты, темы, уведомления ✅  
§6.2 Список чатов ✅  
§7.3–§7.7 (кастомизация, безопасность, интеграции, плагины, upstream sync) ✅  
§8 Web (WSS transport, E2E) ✅  
Сборка на всех платформах (CI + Release) ✅  

§9 Классический дизайн Telegram (до Liquid Glass) ✅  
Дальше: функциональный паритет §6.3+, ручная сверка §9.11.9 — [TODO.md](TODO.md).

## Дизайн

RioGram визуально ориентирован на **официальный Telegram до редизайна Liquid Glass**: плоский UI, акцент `#3390EC`, без frosted glass и blur-панелей. Токены, `context.telegramTheme`, `TelegramIcons`, `ChatWallpaper` и анти-паттерны — в [docs/DESIGN.md](docs/DESIGN.md). Release notes визуального редизайна: [docs/RELEASE_NOTES_1.1.0.md](docs/RELEASE_NOTES_1.1.0.md).

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
- [Дизайн §9 — классический Telegram](docs/DESIGN.md)
- [Release notes 1.1.0 (визуальный редизайн)](docs/RELEASE_NOTES_1.1.0.md)
- [Список чатов (§6.2)](docs/CHATS.md)
- [Настройка прокси](docs/PROXY.md)
- [Патчи TDLib (DPI)](docs/TDLIB_PATCHES.md)
- [Синхронизация с upstream TDLib (§7.7)](docs/TDLIB_UPSTREAM_SYNC.md)
- [Плагины (§7.6)](docs/PLUGINS.md)
- [Web-платформа (§8)](docs/WEB.md)
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
│   ├── tdlib/        # FFI / Web tdlib client
│   ├── auth/         # AuthManager
│   ├── chat/         # ChatManager, parsers, LaTeX
│   ├── proxy/        # ProxyManager, WebProxyManager
│   ├── plugins/      # PluginManager, RioGramPlugin API
│   ├── theme/        # TelegramTheme, ThemeManager
│   ├── privacy/      # SecurityPrivacyManager
│   └── notifications/
├── screens/          # auth, chats, chat, settings
├── widgets/
└── models/
td/                   # Модифицированный TDLib + upstream-base.json
scripts/              # build-tdlib, check-tdlib-upstream, CI helpers
docs/                 # Документация (RU)
.cursor/              # Правила и команды Cursor
```

## Лицензия

GPLv3 with OpenSSL exception.
