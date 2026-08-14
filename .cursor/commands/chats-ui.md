---
command: Справка по UI списка чатов (§6.2)
---

# Список чатов — §6.2

Полная документация: [docs/CHATS.md](../../docs/CHATS.md)

## Ключевые файлы

```
lib/core/chat/chat_manager.dart      # бизнес-логика, TDLib
lib/core/chat/tdlib_chat_parser.dart # парсинг updates
lib/models/chat_models.dart          # ChatSummary, ChatListKey, …
lib/screens/chats/chats_screen.dart  # layout + hotkeys
lib/widgets/chat_list_tile.dart
lib/widgets/chat_folder_sidebar.dart
lib/widgets/chat_desktop_shortcuts.dart
lib/widgets/chat_search_panel.dart
lib/widgets/new_chat_dialog.dart
```

## Breakpoints

- `< 720px` — mobile
- `720–839px` — master-detail (2 col)
- `≥ 840px` — folders | chats | conversation

## Тесты

```bash
flutter test test/chat_models_test.dart
flutter test test/chat_desktop_shortcuts_test.dart
```

## TODO

Чеклист §6.2 в [TODO.md](../../TODO.md) — **закрыт**. Следующий блок: §6.3 (сообщения и переписка).
