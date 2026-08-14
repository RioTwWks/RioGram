# Список чатов и организация (§6.2)

Документация по реализованному функционалу списка чатов RioGram — паритет с официальным Telegram в части организации диалогов (без визуального §9).

**Статус:** §6.2 закрыт (отображение, действия, десктопная навигация).

---

## Архитектура Flutter

| Компонент | Путь | Назначение |
|-----------|------|------------|
| `ChatManager` | `lib/core/chat/chat_manager.dart` | TDLib updates, списки, поиск, pin/archive/delete |
| `TdlibChatParser` | `lib/core/chat/tdlib_chat_parser.dart` | Парсинг chat/position/draft/mute |
| `ChatSummary` и др. | `lib/models/chat_models.dart` | Модели списка, позиций, поиска |
| `ChatsScreen` | `lib/screens/chats/chats_screen.dart` | Адаптивный layout |
| `ChatListTile` | `lib/widgets/chat_list_tile.dart` | Строка чата, swipe, long-press меню |
| `ChatFolderSidebar` | `lib/widgets/chat_folder_sidebar.dart` | Левая колонка папок (desktop) |
| `ChatDesktopShortcuts` | `lib/widgets/chat_desktop_shortcuts.dart` | Горячие клавиши |
| `ChatSearchBar` / `ChatSearchResults` | `lib/widgets/chat_search_panel.dart` | Поиск по чатам и сообщениям |
| `NewChatDialog` | `lib/widgets/new_chat_dialog.dart` | Диалог «Новый чат» |

---

## Адаптивный layout

| Ширина окна | Режим | Описание |
|-------------|-------|----------|
| **< 720px** | Mobile | Push-навигация в `ChatScreen`, горизонтальные вкладки папок |
| **720–839px** | Master-detail | 2 колонки: список чатов (340px) + переписка |
| **≥ 840px** | Desktop 3-column | Папки (72px) \| чаты (340px) \| переписка |

Константы в `ChatsScreen`: `_wideBreakpoint = 720`, `_threeColumnBreakpoint = 840`.

---

## Отображение и сортировка

- **Списки TDLib:** `loadChats` + `updateChatPosition` / `updateChatLastMessage` / `updateChatDraftMessage`
- **Папки:** `updateChatFolders`, переключение через `ChatListTabs` (mobile/2-col) или `ChatFolderSidebar` (3-col)
- **Закрепление:** `toggleChatIsPinned`
- **Архив:** `addChatToList` + свайп влево / пункт меню
- **Mute:** `updateChatNotificationSettings`, иконка колокольчика
- **Черновик:** preview «Черновик: …» с приоритетом над last message
- **Тип чата:** иконки private / group / channel / bot / secret / saved messages
- **Непрочитанные:** badge или синяя точка при `isMarkedAsUnread`

---

## Действия со списком

| Действие | TDLib | UI |
|----------|-------|-----|
| Поиск чатов | `searchChats` | Поле поиска, секция «Чаты» |
| Глобальный поиск сообщений | `searchMessages` | Секция «Сообщения» |
| Очистить историю | `deleteChatHistory(revoke: false)` | Long-press → подтверждение |
| Удалить / покинуть | `deleteChatHistory` / `leaveChat` | Long-press → подтверждение |
| Удалить для всех | `deleteChatHistory(revoke: true)` | Если `can_be_deleted_for_all_users` |
| Отметить непрочитанным | `toggleChatIsMarkedAsUnread` | Long-press меню |
| Избранное | Saved Messages chat | Shortcut + кнопка в AppBar / sidebar |

---

## Горячие клавиши (desktop, ≥720px)

| Комбинация | Действие |
|------------|----------|
| `Ctrl/Cmd+F`, `Ctrl/Cmd+K` | Фокус на поле поиска |
| `Ctrl/Cmd+N` | Диалог «Новый чат» (`searchChats` + `searchChatsOnServer`) |
| `Ctrl/Cmd+↑/↓`, `Alt+↑/↓` | Предыдущий / следующий чат в списке |

Реализация: `ChatDesktopShortcuts` + `Shortcuts` / `Actions` из `package:flutter/services.dart`.

---

## Тесты

```bash
flutter test test/chat_models_test.dart
flutter test test/chat_desktop_shortcuts_test.dart
```

Покрытие: парсинг моделей, сортировка по `ChatPositionInfo`, shortcuts map.

---

## Связанные разделы TODO

- **§6.3+** — сообщения, медиа, группы (ещё не реализовано)
- **§9.2** — визуальная полировка списка чатов «как классический Telegram»
