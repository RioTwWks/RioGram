# Side-by-side чеклист §9.11.9

Ручная сверка RioGram с Telegram Desktop / Android (светлая + тёмная, 799/800/840px).

Автоматическая регрессия (widget-тесты, без golden): `telegram_refinement_test.dart`, `chat_list_tile_test.dart`, `message_bubble_test.dart`, `message_input_bar_test.dart`, `telegram_settings_tile_test.dart`, `desktop_layout_regression_test.dart`, `empty_state_test.dart`, `telegram_icons_audit_test.dart`.

Гайд для разработчиков: [DESIGN.md](DESIGN.md).

## Легенда

- `[x]` — покрыто widget-тестами / реализацией; ручная сверка рекомендуется
- `[ ]` — требует ручной side-by-side сверки или backlog §9.11

## Экраны

- [x] Список чатов — row 72px (`TelegramSpacing.chatListRowHeight`), divider inset
- [x] Список чатов — галочки preview исходящих (`MessageDeliveryIcon` в `ChatListTile`)
- [x] Список чатов — пустое состояние SVG (`empty_state_test.dart`)
- [ ] Список чатов — typing / «записывает голосовое…» в preview (§9.11.2 backlog)
- [ ] Список чатов — hover / selected desktop `#3390EC` @ 8%
- [ ] Список чатов — FAB отступ 16px + safe area (mobile)
- [x] Переписка — wallpaper doodle (`ChatWallpaper`)
- [x] Переписка — bubbles, Bezier tail, inline meta (`message_bubble_test.dart`)
- [x] Переписка — дата-разделитель и service messages (`date_separator_test.dart`)
- [x] Переписка — «Выберите чат» (`empty_state_test.dart`)
- [x] Панель ввода — mic/send 48px (`message_input_bar_test.dart`)
- [x] Панель ввода — sticker panel ~320px
- [x] Настройки — row 48px, section headers (`telegram_settings_tile_test.dart`)
- [x] Настройки — chevron, divider inset
- [x] Desktop — три колонки, folder sidebar 68px (`desktop_layout_regression_test.dart`)
- [x] Звонок — accept/decline, spacing 24px (реализация §9.8 / §9.11.8)

## Иконография §9.9

- [x] Launcher pipeline `flutter_launcher_icons`, accent `#3390EC` — [APP_ICON.md](APP_ICON.md)
- [x] `TelegramIcons` outline 24dp в chat UI (`telegram_icons_audit_test.dart`)

## Критерий готовности §9.11

Два скриншота (светлая + тёмная) RioGram и TG Desktop рядом — отличия только в логотипе и RioGram-фишках; отступы в пределах ±2px.
