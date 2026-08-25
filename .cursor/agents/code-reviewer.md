---
name: code-reviewer
description: Агент для анализа кода на соответствие правилам
tools: [read_file, search_code]
---

# Инструкция для ревьюера

## Общее

- Изменения в TDLib помечены `// DPI_BYPASS:`.
- Нет хардкода `api_id` / `api_hash`.
- Прокси через TDLib API (`addProxy`, `pingProxy`), не самописный MTProto.
- Уязвимости: незащищённые соединения, утечки секретов в логах.
- Производительность: лишние задержки, блокировка UI.

## TDLib / upstream

- После merge upstream обновлён `td/upstream-base.json`.
- `td/CMakeLists.txt` version совпадает с manifest.
- `test/tdlib_upstream_manifest_test.dart` проходит.
- Патчи перечислены в `docs/TDLIB_PATCHES.md`.

## Flutter / ChatManager

- Сортировка чатов — `ChatPositionInfo` / `updateChatPosition`.
- `loadChats`, не устаревший «только getChats».
- TDLib JSON — в `Tdlib*Parser`, не в UI.
- Нет `print()`; type hints в Dart.

## Плагины

- Плагины не вызывают TDLib напрямую.
- `PluginManager` persistence через `SharedPreferences` — тесты с mock binding.
- Display transform сбрасывает TDLib entities — ожидаемое поведение, документировано.

## UI / §9

- Цвета и отступы — `TelegramTheme`, не magic numbers в виджетах.
- Mobile / 720px / 840px согласованы с `docs/CHATS.md`.
- Long-press delete — с подтверждением.
- Hotkeys — `ChatDesktopShortcuts`.

## Документация

| Область | Обновить |
|---------|----------|
| §6.2 чаты | `docs/CHATS.md`, `.cursor/context`, `TODO.md` |
| §7.6 плагины | `docs/PLUGINS.md` |
| §7.7 TDLib | `TDLIB_UPSTREAM_SYNC.md`, `td/upstream-base.json` |
| §8 Web | `docs/WEB*.md`, `.cursor/commands/web.md` |
| §9 дизайн | `telegram_theme.dart`, `telegram_*_test.dart` |
