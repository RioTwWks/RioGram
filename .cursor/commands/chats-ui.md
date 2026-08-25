---
command: Справка по UI списка чатов (§6.2)
---

# Список чатов — §6.2 ✅

Полная документация: [docs/CHATS.md](../../docs/CHATS.md)

## Ключевые файлы

```
lib/core/chat/chat_manager.dart
lib/core/chat/tdlib_chat_parser.dart
lib/models/chat_models.dart
lib/screens/chats/chats_screen.dart
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
flutter test test/chat_list_tile_test.dart
flutter test test/chat_desktop_shortcuts_test.dart
```

## Связанные разделы

- §6.3+ сообщения и переписка — `lib/screens/chat/`, `MessageBubble`
- §9 дизайн списка — `telegram_theme.dart`, `telegram_refinement_test.dart`
- Чеклист: [TODO.md](../../TODO.md) §6
