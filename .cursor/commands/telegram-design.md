---
command: Справка по дизайну §9 — классический Telegram
---

# Дизайн §9 / §9.11 ✅

Полная документация: [docs/DESIGN.md](../../docs/DESIGN.md)  
Release notes: [docs/RELEASE_NOTES_1.1.0.md](../../docs/RELEASE_NOTES_1.1.0.md)  
Чеклист: [TODO.md](../../TODO.md) §9, §9.11  
Ручная сверка: [docs/SIDE_BY_SIDE_CHECKLIST.md](../../docs/SIDE_BY_SIDE_CHECKLIST.md)

## Ключевые файлы

```
lib/core/theme/telegram_theme.dart    # TelegramColors, TelegramSpacing, TelegramThemeData
lib/core/theme/telegram_icons.dart    # TelegramIcons (outline 24dp)
lib/widgets/chat_wallpaper.dart       # ChatWallpaper (doodle pattern)
lib/widgets/telegram_settings_tile.dart
lib/widgets/chat_list_tile.dart
lib/widgets/message_bubble.dart
lib/widgets/message_input_bar.dart
lib/widgets/message_delivery_icon.dart
lib/widgets/scroll_to_bottom_button.dart
lib/widgets/chat_folder_sidebar.dart
lib/screens/chats/chats_screen.dart
lib/screens/chat/chat_screen.dart
lib/screens/settings/settings_screen.dart
```

## Правила

- Цвета и отступы: `context.telegramTheme`, не хардкод TG-цветов
- Запрещено: `BackdropFilter`, blur AppBar/tab bar, drop-shadow на пузырях
- M3 chips в chat UI → `TelegramFlatChip`; elevation shell → 0
- Кастомизация §7.3 поверх §9: `ThemeManager`, `UiCustomizationPreferences`

## Тесты

```bash
# Быстрая проверка токенов §9.11
flutter test test/telegram_refinement_test.dart

# Полный набор регрессии дизайна
flutter test test/telegram_theme_test.dart
flutter test test/telegram_icons_audit_test.dart
flutter test test/chat_list_tile_test.dart
flutter test test/message_bubble_test.dart
flutter test test/message_bubble_grouping_test.dart
flutter test test/message_input_bar_test.dart
flutter test test/telegram_settings_tile_test.dart
flutter test test/desktop_layout_regression_test.dart
flutter test test/empty_state_test.dart
flutter test test/date_separator_test.dart
flutter test test/message_delivery_icon_test.dart
```

Golden-тесты в CI headless не используются — см. комментарий в `telegram_refinement_test.dart`.

## Breakpoints (§9.5)

| Ширина | Layout |
|--------|--------|
| `< 800px` | Mobile |
| `800–839px` | Master-detail |
| `≥ 840px` | Папки \| чаты \| переписка |

Константы: `TelegramLayoutBreakpoints` в `telegram_theme.dart`.

## Связанные разделы

- §6 функционал экранов — оформляется по §9
- §7.3 кастомизация сверх классического вида — настройки `ui_customization_*`
- Иконка приложения — [docs/APP_ICON.md](../../docs/APP_ICON.md)
