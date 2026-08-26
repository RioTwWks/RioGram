# RioGram 1.1.0 — визуальный редизайн (§9 + §9.11)

**Тема релиза:** классический вид Telegram до Liquid Glass — плоский, читаемый интерфейс без frosted glass, размытых панелей и «стеклянных» эффектов iOS 26 / macOS Tahoe.

**Референсы:** Telegram Desktop 4.x–5.x, Telegram Android / iOS до полупрозрачных tab bar и blur-эффектов, [Telegram UI Kit](https://www.figma.com/community/file/867601279089856700) (community).

---

## Краткое резюме

RioGram 1.1.0 — крупный визуальный релиз. Интерфейс приведён к классическому Telegram: единая дизайн-система `TelegramTheme`, обновлённые экраны чатов и переписки, плоская навигация, настройки в стиле TG Settings, медиа-сообщения и экраны звонков. Фаза **§9.11 (pixel parity)** довела отступы, размеры и микро-детали до целевых констант (72 / 56 / 48 px) и добавила widget-регрессию.

Если вы пользователь — заметите более «телеграмный» вид: серые фоны, синий акцент `#3390EC`, плоские пузыри с хвостом, галочки доставки в списке чатов, doodle-обои переписки, трёхколоночный layout на Desktop.

Если вы разработчик — все цвета и размеры централизованы в `lib/core/theme/telegram_theme.dart`; гайд: [DESIGN.md](DESIGN.md).

---

## Что изменилось — по экранам

### Список чатов (§9.2, §9.11.2)

Главный экран приложения переработан под классический Telegram:

- **Строка чата** — фиксированная высота **72 px** (`TelegramSpacing.chatListRowHeight`): слева круглый аватар **48 px**, по центру имя (semibold, одна строка) и preview последнего сообщения, справа время и badge непрочитанных.
- **Preview исходящих** — галочки статуса доставки (✓ отправлено / ✓✓ доставлено / прочитано) через `MessageDeliveryIcon` в `ChatListTile`.
- **Групповые чаты** — префикс имени отправителя в preview (`Имя:`).
- **Индикаторы активности** — «печатает…», «записывает голосовое…» в preview строки.
- **Закреплённые и без звука** — иконка булавки для pin, перечёркнутый колокольчик для mute, сниженная opacity preview у muted-чатов.
- **Badge непрочитанных** — синий круг `#3390EC`, белый текст, min-width **20 px**.
- **Разделитель** — hairline 1 px с inset после аватара (как в TG), не на всю ширину.
- **Поле поиска** — скруглённое, фон `#F0F0F0` / `#242F3D` (dark), **без blur**.
- **FAB «Новое сообщение»** — синий круг с иконкой карандаша, elevation **0**, отступ снизу 16 px + safe area.
- **Desktop** — hover / selected state с подсветкой `#3390EC` @ 8 %.
- **Пустые состояния** — SVG-иллюстрации: «Нет чатов», «Пустая папка», «Нет результатов поиска» (`assets/illustrations/`).

### Экран переписки (§9.3, §9.11.3)

Переписка — самый заметный визуальный апдейт:

- **AppBar** — сплошной фон темы (не прозрачный blur), высота **56 px**; аватар + имя + статус («в сети», «был(а) недавно», «печатает…») 13 sp secondary; иконки поиска и меню.
- **Фон чата** — виджет `ChatWallpaper`: нейтральный серый / белый + программный doodle-паттерн (как TG Android); на Desktop узор слабее (`isDesktopChatBackground`).
- **Пузыри** — исходящие справа (`#EFFEDE` / `#2B5278`), входящие слева (`#FFFFFF` / `#182533`); max-width ~75 %; **без drop-shadow**.
- **Хвост пузыря** — Bezier-path вместо упрощённого треугольника; группировка соседних сообщений одного отправителя (меньший отступ, скругление только с внешней стороны).
- **Meta-строка** — время и галочки **в последней строке текста** (inline float-right spacer), 11 sp; baseline alignment внутри пузыря.
- **Имена в группах** — цветные, 13 sp, над первым пузырём в серии.
- **Reply quote** — вертикальная accent-полоса, tinted фон ~12 %, radius **5 px**.
- **Link preview** — карточка со скруглением, thumbnail и доменом (`LinkPreviewWidget`).
- **Сервисные сообщения** — центрированная капсула `#00000033` / `#FFFFFF33`, без пузыря.
- **Дата-разделители** — капсула по центру: «15 августа», фон `#0000004D` / `#FFFFFF33`, белый текст.
- **Кнопка «↓ N новых»** — capsule radius 16 px, отступ от низа 8 px, elevation 0.
- **Иконки доставки** — `TelegramIcons.deliverySent` / `deliveryDelivered` + виджет `MessageDeliveryIcon` (sent / delivered / read).

### Панель ввода (§9.4, §9.11.4)

Composer приведён к классическому Telegram:

- **Нижняя панель** — сплошной фон, border-top 1 px цвета divider темы, **без glass effect**.
- **Слева** — скрепка (вложения) или эмодзи; **справа** — микрофон или синяя круглая кнопка «Отправить» при непустом тексте.
- **Touch target** микрофона и send — **≥ 48×48 px** (`TelegramSpacing.inputTouchTarget`).
- **Поле ввода** — radius **20 px**, фон `#F0F0F0` / `#242F3D`, placeholder «Сообщение» серым.
- **Reply / edit strip** — компактная полоса над полем: accent bar **2 px**, отступы 8×12, крестик отмены.
- **Панель стикеров / GIF** — выезжает снизу, высота **~320 px**, табы наборов, сетка 4–5 колонок.
- **Attach sheet** — единая линия вложений (фото, документ, опрос и т.д.) в стиле TG.

### Навигация (§9.5, §9.11.5)

Навигация адаптирована под платформу без M3-утечек:

#### Mobile (Android / iOS)

- Нижний **tab bar**: Чаты | Контакты | Настройки.
- Сплошной фон, иконки outline **24 dp**, label **10 sp**, активная вкладка — accent blue.
- iOS: `isTranslucent: false` — без прозрачного UITabBar blur.

#### Desktop (Windows / macOS / Linux)

- **Три колонки**: папки **~68 px** | список чатов **~340 px** | переписка (flex).
- **Resize handle** между списком чатов и перепиской (4 px).
- Минимальная ширина окна **~800 px**; при сужении — mobile master-detail.
- `ChatFolderSidebar`: цвета из `telegramTheme`, выделение — левая accent-полоса.

#### Общее

- Breakpoints: mobile **800 px**, three-column **840 px** (`TelegramLayoutBreakpoints`).
- Переходы: slide horizontal для push-экранов, fade **150–200 ms**.
- **Flat shell (§9.11.10):** устранены M3 elevation, `ActionChip` / `FilterChip` → `TelegramFlatChip`; FAB и кнопка «↓ N новых» с elevation 0.

### Настройки и профиль (§9.6, §9.11.6, §9.11.11)

Экраны настроек оформлены как TG Settings:

- **Секционные заголовки** — uppercase 12 sp secondary, top padding **24 px**, bottom **8 px** (`TelegramSettingsSectionHeader`).
- **Строки настроек** — min-height **48 px**, title слева, value / chevron справа, divider inset (`TelegramSettingsTile`, `TelegramSettingsSwitchTile`).
- **Профиль** — аватар **120 px** (`profileScreenAvatarRadius`), имя, @username, телефон.
- **Переключатели** — Material / Cupertino Switch, accent `#3390EC`.
- **Desktop** — плоские группы настроек на широких экранах (без карточек с elevation).
- **Экран прокси RioGram** — встроен в общий стиль настроек, не выбивается визуально.
- **Цветные placeholder-аватары** — `ChatAvatar` + `TelegramAvatarColors` (палитра как в TG).

### Медиа и спец-сообщения (§9.7, §9.11.7)

Медиа-сообщения получили pixel-parity детали:

- **Голосовые** — горизонтальная waveform: **34** bars, ширина **5 px**, gap **2 px**; кнопка play, длительность; исходящие на зеленоватом фоне пузыря.
- **Видео** — превью с play по центру; badge длительности **11 sp**, padding **4×6** (`VideoDurationBadge`).
- **Кружочки (video note)** — круглое превью **240 px**.
- **Стикеры** — без пузыря (прозрачный фон), без тени.
- **Документы** — иконка типа + имя + размер, min-height карточки **56 px**.
- **Геолокация** — статическая карта-превью, radius **8 px**.
- **Полноэкранный viewer** — чёрный фон, свайп между медиа, pinch-zoom.

### Звонки и уведомления (§9.8, §9.11.8)

Экраны звонков в классическом стиле:

- **Входящий звонок** — полноэкранный overlay; размытый аватар + градиент на фоне (не glass-панели); имя абонента; зелёная «Принять» (`#4CB050`) / красная «Отклонить» (`#E53935`); опциональная пульсация вокруг кнопки «Принять».
- **Активный звонок** — тёмный фон `#000000`, крупные круглые кнопки управления (72 / 64 px), spacing **24 px**.
- **Локальные уведомления** — иконка приложения, системный стиль (не кастомный glass banner).

### Иконография и иллюстрации (§9.9)

Единая иконографическая система:

- **`TelegramIcons`** — централизованный маппинг Material Icons outline **24 dp** → действия Telegram (чаты, контакты, настройки, attach, mic, send, доставка, типы чатов и т.д.). Файл: `lib/core/theme/telegram_icons.dart`.
- **Иконка приложения** — pipeline `flutter_launcher_icons`, accent `#3390EC`; мастер `assets/icons/app_icon_1024.png`. Подробности: [APP_ICON.md](APP_ICON.md).
- **Пустые состояния** — SVG в `assets/illustrations/` (`empty_no_chats`, `empty_select_chat`, `empty_contacts`, `empty_search`, `empty_archive`, `empty_folder`).
- **Аудит** — `test/telegram_icons_audit_test.dart` проверяет использование `TelegramIcons` в chat UI.

---

## Дизайн-система и токены (§9.1, §9.11.1)

Все визуальные константы собраны в `lib/core/theme/telegram_theme.dart`:

### Цвета (`TelegramColors`)

| Элемент | Светлая тема | Тёмная тема |
|---------|--------------|-------------|
| Акцент / ссылки | `#3390EC` | `#3390EC` |
| Фон списка чатов | `#FFFFFF` | `#17212B` |
| Фон переписки | `#E6EBEE` (mobile) / `#FFFFFF` (desktop) | `#0E1621` |
| Исходящий пузырь | `#EFFEDE` | `#2B5278` |
| Входящий пузырь | `#FFFFFF` | `#182533` |
| Текст primary | `#000000` | `#FFFFFF` |
| Текст secondary | `#707579` | `#707579` |
| Время / meta | `#8E8E93` | `#8E8E93` |

Контраст текста в пузырях — **WCAG AA**.

### Типографика (`TelegramTypography`, `TelegramFontSizes`)

- Android: **Roboto**
- iOS: **SF Pro** (системный)
- Desktop (Windows / Linux / macOS): **Open Sans** через `google_fonts`
- Размеры: заголовок чата 16 sp, сообщение 16 sp, preview 14 sp, время 12 sp, meta в пузыре 11 sp, подзаголовок AppBar 13 sp

### Размеры (`TelegramSpacing`, `TelegramMediaSpacing`)

| Константа | Значение | Где применяется |
|-----------|----------|-----------------|
| `chatListRowHeight` | 72 px | `ChatListTile` |
| `chatAppBarHeight` | 56 px | AppBar переписки |
| `settingsRowHeight` | 48 px | `TelegramSettingsTile` |
| `chatListHorizontalPadding` | 12 px | Список чатов |
| `inputTouchTarget` | 48 px | Mic / send |
| `stickerPanelHeight` | 320 px | Панель стикеров |
| `folderSidebarWidth` | 68 px | Desktop sidebar папок |
| `profileScreenAvatarRadius` | 60 px (Ø 120) | Экран профиля |
| `waveformBarCount` | 34 | Голосовые |
| `documentCardMinHeight` | 56 px | Документы |

### Скругления (`TelegramRadii`)

Пузырь 12–18 px (больший у «хвоста»), input 20 px, badge 10 px, media preview 8 px. **Без drop-shadow** — плоский классический стиль.

### Доступ к теме в коде

```dart
final tg = context.telegramTheme;
// tg.accent, tg.chatListBackground, tg.bubbleOutgoing, tg.textSecondary, …
```

`TelegramThemeData` регистрируется как `ThemeExtension` в `TelegramTheme.light()` / `TelegramTheme.dark()`. **Не хардкодить** `Color(0xFF3390EC)` в виджетах — брать из темы.

Кастомизация §7.3 (акцент, скругления) — через `ThemeManager` и `UiCustomizationPreferences`; базовая палитра §9 остаётся в `telegram_theme.dart`.

---

## Что намеренно НЕ изменилось

### Анти-паттерны Liquid Glass (`TelegramDesignConstraints`)

RioGram **не** копирует новый Telegram с frosted glass. Зафиксировано в коде и тестах:

| Запрещено | Почему |
|-----------|--------|
| `BackdropFilter` / `ImageFilter.blur` на панелях | Frosted glass |
| Полупрозрачные AppBar / tab bar | Новый TG / iOS 26 |
| Drop-shadow на пузырях и FAB | Плоский классический стиль |
| Neumorphism, «стеклянные» капсулы | Liquid Glass |
| `ActionChip` / M3 elevation в chat UI | Используй `TelegramFlatChip`, elevation 0 |

**Исключение:** входящий звонок может размывать **фон аватара** (не glass-панели) — §9.8.

### Функциональность и уникальные фишки RioGram

- **Функциональный паритет §6.3+** — отдельные релизы; этот апдейт только визуальный.
- **Уникальная кастомизация §7.3** (произвольные шрифты, скрытие UI) — не затронута; работает поверх базового §9.
- **DPI / прокси / TDLib** — без изменений в рамках дизайн-релиза.
- **Пользовательский wallpaper** в информации о чате — низкий приоритет, не реализован.

---

## Качество, регрессия и известные ограничения

### Автоматическая регрессия (§9.11.9)

Widget-тесты покрывают константы и ключевые виджеты (без golden в CI headless):

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

Покрыто: светлая и тёмная темы, breakpoints Desktop **800 / 840 px**, группировка пузырей, inline meta, delivery icons, settings tiles, empty states.

### Ручная сверка (backlog §9.11.9)

Side-by-side чеклист: [SIDE_BY_SIDE_CHECKLIST.md](SIDE_BY_SIDE_CHECKLIST.md).

Пункты, требующие ручной сверки с Telegram Desktop / Android:

- Typing / «записывает голосовое…» в preview списка чатов
- Hover / selected state на Desktop (`#3390EC` @ 8 %)
- FAB отступ 16 px + safe area на конкретных устройствах
- Полный проход: список чатов | переписка | ввод | настройки | звонок (светлая + тёмная)

**Критерий готовности §9.11:** два скриншота RioGram и TG Desktop рядом — отличия только в логотипе и уникальных RioGram-фишках; отступы в пределах **±2 px**.

### Что не входит в 1.1.0

- Пользовательский wallpaper в информации о чате
- Фото-обои с blur в `ChatWallpaper` (запланировано позже)
- Golden-тесты в CI (headless-окружение не поддерживает стабильный рендер)
- Полный функциональный паритет §6

---

## История изменений (ключевые PR)

| Фаза | Ветка / PR | Область |
|------|------------|---------|
| D1 | `cursor/telegram-design-tokens-ca50` (#68) | Токены, светлая/тёмная тема |
| D2 | `cursor/telegram-chat-list-ca50` (#75), `cursor/telegram-chat-screen-ca50` (#77) | Список чатов, переписка |
| D3 | `cursor/telegram-input-panel-ca50` (#72), `cursor/telegram-settings-profile-ca50` (#76) | Ввод, настройки |
| D4 | `cursor/telegram-navigation-ca50` (#71), `cursor/telegram-media-messages-ca50` (#74) | Навигация, медиа |
| D5 | `cursor/telegram-calls-notifications-ca50` (#73), `cursor/telegram-icons-illustrations-ca50` (#70) | Звонки, иконки |
| R1–R11 | `cursor/telegram-refine-*-ca50` (#89–#116) | Pixel parity §9.11 |
| Docs | `cursor/docs-telegram-design-ca50` (#117) | DESIGN.md, Cursor rules |

---

## Для разработчиков

| Ресурс | Описание |
|--------|----------|
| [DESIGN.md](DESIGN.md) | Гайд по дизайн-системе, токенам, анти-паттернам |
| [TODO.md §9](TODO.md#9-дизайн-в-стиле-классического-telegram-до-liquid-glass) | Полный чеклист реализации |
| [SIDE_BY_SIDE_CHECKLIST.md](SIDE_BY_SIDE_CHECKLIST.md) | Ручная сверка pixel parity |
| [APP_ICON.md](APP_ICON.md) | Pipeline иконки приложения |
| `.cursor/commands/telegram-design.md` | Команда Cursor для дизайн-задач |
| `.cursor/rules/flutter.mdc` | Правила Flutter-разработки |

**Ключевые файлы:**

- `lib/core/theme/telegram_theme.dart` — палитра, spacing, constraints
- `lib/core/theme/telegram_icons.dart` — иконки
- `lib/widgets/chat_wallpaper.dart` — фон переписки
- `lib/widgets/chat_list_tile.dart` — строка списка чатов
- `lib/widgets/message_bubble.dart` — пузыри
- `lib/widgets/message_input_bar.dart` — панель ввода
- `lib/widgets/telegram_settings_tile.dart` — настройки

---

*RioGram 1.1.0 — визуальный релиз. Следующий фокус: функциональный паритет §6 и завершение ручной сверки §9.11.9.*
