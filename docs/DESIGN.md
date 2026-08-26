# Дизайн RioGram — классический Telegram (§9)

RioGram визуально ориентирован на **официальный Telegram до редизайна Liquid Glass** (iOS 26 / macOS Tahoe): плоский UI, читаемые серые фоны, акцент `#3390EC`, без frosted glass и blur-панелей.

Детальный чеклист реализации: [TODO.md §9](TODO.md#9-дизайн-в-стиле-классического-telegram-до-liquid-glass) и pixel parity [§9.11](TODO.md#911-визуальная-полировка-pixel-parity).

## Референсы

- Telegram Desktop 4.x–5.x (трёхколоночный layout)
- Telegram Android / iOS **до** полупрозрачных tab bar и blur
- [Telegram UI Kit](https://www.figma.com/community/file/867601279089856700) (community) — отступы и компоненты

Расширенная кастомизация **поверх** классического вида (шрифты, скрытие UI) — §7.3, не §9.

## Центральные файлы

| Файл | Назначение |
|------|------------|
| `lib/core/theme/telegram_theme.dart` | `TelegramColors`, `TelegramSpacing`, `TelegramThemeData`, `TelegramTheme`, `TelegramDesignConstraints` |
| `lib/core/theme/telegram_icons.dart` | `TelegramIcons` — outline 24dp, единый маппинг Material Icons |
| `lib/widgets/chat_wallpaper.dart` | `ChatWallpaper` — doodle-паттерн фона переписки |
| `lib/widgets/telegram_settings_tile.dart` | `TelegramSettingsTile`, `TelegramSettingsSwitchTile`, `TelegramSettingsSectionHeader` |
| `lib/widgets/chat_list_tile.dart` | Строка списка чатов (72px, preview, badge) |
| `lib/widgets/message_bubble.dart` | Пузыри, tail, meta-строка, reply quote |
| `lib/widgets/message_input_bar.dart` | Панель ввода, mic/send 48px, sticker panel |

## `context.telegramTheme`

Расширение `TelegramThemeContext` на `BuildContext`:

```dart
final tg = context.telegramTheme;
// tg.accent, tg.chatListBackground, tg.bubbleOutgoing, tg.textSecondary, …
```

`TelegramThemeData` регистрируется как `ThemeExtension` в `TelegramTheme.light()` / `TelegramTheme.dark()`. **Не** хардкодить `Color(0xFF3390EC)` и серые фоны в виджетах — брать из темы.

Кастомизация §7.3 (акцент, скругления) — через `ThemeManager` и `UiCustomizationPreferences`; базовая палитра §9 остается в `telegram_theme.dart`.

## Ключевые токены

### Цвета

| Токен | Светлая | Тёмная |
|-------|---------|--------|
| Акцент | `#3390EC` | `#3390EC` |
| Фон списка чатов | `#FFFFFF` | `#17212B` |
| Фон переписки | `#E6EBEE` (mobile) / `#FFFFFF` (desktop) | `#0E1621` |
| Исходящий пузырь | `#EFFEDE` | `#2B5278` |
| Входящий пузырь | `#FFFFFF` | `#182533` |
| Текст secondary | `#707579` | `#707579` |

Константы: `TelegramColors` в `telegram_theme.dart`.

### Размеры (§9.11)

| Константа | Значение | Применение |
|-----------|----------|------------|
| `TelegramSpacing.chatListRowHeight` | 72px | `ChatListTile` |
| `TelegramSpacing.chatAppBarHeight` | 56px | AppBar переписки |
| `TelegramSpacing.settingsRowHeight` | 48px | `TelegramSettingsTile` |
| `TelegramSpacing.chatListHorizontalPadding` | 12px | Список чатов |
| `TelegramSpacing.inputTouchTarget` | 48px | Mic / send |
| `TelegramSpacing.stickerPanelHeight` | 320px | Панель стикеров |
| `TelegramSpacing.folderSidebarWidth` | 68px | Desktop sidebar папок |

Breakpoints: `TelegramLayoutBreakpoints` — mobile 800px, three-column 840px, ширина списка чатов 340px.

### Типографика

- Android: Roboto, iOS: SF Pro (системный), Desktop: **Open Sans** (`google_fonts`, `TelegramTypography.platformFontFamily`)
- Размеры: `TelegramFontSizes` — сообщение 16sp, preview 14sp, время 12sp, meta в пузыре 11sp

### Скругления

`TelegramRadii` — пузырь 12–18px, input 20px, badge 10px. Плоский стиль: **без** drop-shadow на пузырях.

## `TelegramIcons`

Централизованный набор в `lib/core/theme/telegram_icons.dart`:

- Навигация: `chats`, `contacts`, `settings`
- Чат: `attach`, `emoji`, `mic`, `send`, `search`, `moreVert`
- Доставка: `deliverySent`, `deliveryDelivered` (+ `MessageDeliveryIcon` виджет)
- Типы чатов: `privateChat`, `group`, `channel`, `bot`, `secretChat`

Базовый размер: `TelegramIcons.size` = 24dp. Аудит: `test/telegram_icons_audit_test.dart`.

## `ChatWallpaper`

Виджет фона переписки: сплошной `tg.chatBackground` + программный doodle-тайл (`CustomPaint`). На desktop узор слабее (`isDesktopChatBackground`). Фото-обои пользователя — низкий приоритет (§9.3 TODO).

## Настройки

Группы в `ListView` с `TelegramSettingsSectionHeader` (uppercase 12sp, top 24 / bottom 8). Строки — `TelegramSettingsTile` / `TelegramSettingsSwitchTile` (min-height 48px, divider inset). Профиль: аватар 120px (`profileScreenAvatarRadius`).

## Анти-паттерны (Liquid Glass)

Зафиксированы в `TelegramDesignConstraints` и тесте `telegram_refinement_test.dart`:

| Запрещено | Почему |
|-----------|--------|
| `BackdropFilter` / `ImageFilter.blur` на панелях | Frosted glass |
| Полупрозрачные AppBar / tab bar | Новый TG / iOS 26 |
| Drop-shadow на пузырях и FAB | Плоский классический стиль |
| Neumorphism, «стеклянные» капсулы | Liquid Glass |
| `ActionChip` / M3 elevation в chat UI | Используй `TelegramFlatChip`, elevation 0 |

Исключение: входящий звонок может использовать размытие **фона аватара** (не glass-панели) — §9.8.

## Регрессия и тесты

```bash
flutter test test/telegram_refinement_test.dart
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

Golden-тесты в CI headless **не** используются — см. комментарий в `telegram_refinement_test.dart`.

Ручная сверка side-by-side: [SIDE_BY_SIDE_CHECKLIST.md](SIDE_BY_SIDE_CHECKLIST.md).

## Иконка приложения

Launcher и pipeline `flutter_launcher_icons`: [APP_ICON.md](APP_ICON.md).

## Cursor

- Правила: `.cursor/rules/flutter.mdc`
- Команда: `.cursor/commands/telegram-design.md`
