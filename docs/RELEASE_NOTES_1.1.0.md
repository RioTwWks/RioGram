# RioGram 1.1.0 — визуальный редизайн (§9)

**Тема релиза:** классический вид Telegram до Liquid Glass — плоский, читаемый интерфейс без frosted glass и blur-панелей.

---

## Обзор

Версия 1.1.0 посвящена визуальному паритету с официальным Telegram Desktop 4.x–5.x и мобильными клиентами до редизайна iOS 26. Обновлены токены дизайна, список чатов, переписка, навигация, настройки, медиа и звонки. Дополнительная полировка §9.11 довела отступы и микро-детали до целевых констант (72px / 56px / 48px).

Документация для разработчиков: [DESIGN.md](DESIGN.md).

---

## Дизайн-система и токены (§9.1, §9.11.1)

- Единая палитра в `TelegramTheme`: акцент `#3390EC`, светлая и тёмная темы
- Плоские пузыри без теней; WCAG AA для текста в пузырях
- Типографика: Roboto / SF Pro / **Open Sans** на Desktop
- Константы pixel parity: высота строки чата 72px, AppBar переписки 56px, строка настроек 48px
- `TelegramDesignConstraints` — явный запрет blur, glass и drop-shadow в shell UI

---

## Список чатов (§9.2, §9.11.2)

- Строка чата: аватар 48px, имя, preview, время, badge непрочитанных
- Галочки доставки в preview исходящих сообщений (✓ / ✓✓)
- Pin, mute, разделитель с inset после аватара
- Поле поиска со скруглением, фон `#F0F0F0`, без blur
- FAB «Новое сообщение» — синий круг, elevation 0
- Пустое состояние с SVG-иллюстрацией

---

## Переписка и пузыри (§9.3, §9.11.3)

- Фон чата: `ChatWallpaper` с doodle-паттерном (как TG Android)
- Пузыри с Bezier-хвостом, группировка, цветные имена в группах
- Meta-строка: время и галочки в последней строке текста (inline float-right)
- Reply quote: tinted accent ~12%, radius 5px
- Сервисные сообщения и дата-разделители в стиле TG (капсулы `#0000004D` / `#FFFFFF33`)
- Link preview card, кнопка «↓ N новых сообщений»
- Иконки доставки: `TelegramIcons` + `MessageDeliveryIcon` (sent / delivered / read)

---

## Панель ввода (§9.4, §9.11.4)

- Сплошной фон, border-top 1px, без glass effect
- Touch target микрофона и send ≥ 48×48px
- Поле ввода radius 20px; reply/edit strip с accent bar 2px
- Панель стикеров ~320px, табы наборов

---

## Навигация (§9.5, §9.11.5)

- Mobile: нижний tab bar с сплошным фоном, accent blue на активной вкладке
- Desktop: три колонки (папки ~68px | чаты ~340px | переписка), resize handle
- Breakpoints 800px / 840px; переходы 150–200ms
- Устранены M3-утечки: flat shell, `TelegramFlatChip` вместо ActionChip

---

## Настройки и профиль (§9.6, §9.11.6)

- Секционные заголовки, строки 48px, `TelegramSettingsTile`
- Профиль: аватар 120px, имя, @username, телефон
- Экран прокси RioGram в едином стиле TG Settings
- Плоские группы настроек на широких экранах (desktop)

---

## Медиа и спец-сообщения (§9.7, §9.11.7)

- Голосовые: waveform 34 bars, 5px / gap 2px
- Видео: badge длительности 11sp, padding 4×6
- Кружочки, стикеры без пузыря, документ min-height 56px
- Полноэкранный viewer: чёрный фон, зум, свайп

---

## Звонки (§9.8, §9.11.8)

- Входящий: полноэкранный overlay, зелёная «Принять» / красная «Отклонить»
- Активный звонок: тёмный фон, круглые кнопки, spacing 24px
- Опциональная пульсация на кнопке «Принять»

---

## Иконография (§9.9)

- `TelegramIcons`: outline 24dp, единый маппинг в chat UI
- Иконка приложения: pipeline `flutter_launcher_icons`, accent `#3390EC` — [APP_ICON.md](APP_ICON.md)
- Аудит иконок: `telegram_icons_audit_test.dart`

---

## Качество и регрессия (§9.11.9)

- Widget-тесты констант и ключевых виджетов (без golden в CI headless)
- Тёмная тема: второй проход pixel parity
- Desktop layout regression на 800px / 840px
- Ручной side-by-side чеклист: [SIDE_BY_SIDE_CHECKLIST.md](SIDE_BY_SIDE_CHECKLIST.md)

---

## Что не входит в 1.1.0

- Пользовательский wallpaper в информации о чате (низкий приоритет)
- Некоторые пункты §9.11.2 (typing в preview, hover desktop, FAB safe area) — в backlog
- Функциональный паритет §6.3+ — отдельные релизы
- Уникальные фишки RioGram §7 — не затронуты этим визуальным релизом

---

## Для разработчиков

- Гайд: [DESIGN.md](DESIGN.md)
- Чеклист задач: [TODO.md §9](TODO.md#9-дизайн-в-стиле-классического-telegram-до-liquid-glass)
- Тесты: `flutter test test/telegram_refinement_test.dart` и связанные `telegram_*_test.dart`
