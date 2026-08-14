---
name: code-reviewer
description: Агент для анализа кода на соответствие правилам
tools: [read_file, search_code]
---

# Инструкция для ревьюера

## Общее

- Проверь, что все изменения в TDLib помечены комментарием `// DPI_BYPASS:`.
- Убедись, что нет хардкода `api_id` и `api_hash`.
- Проверь, что используются правильные методы TDLib для прокси.
- Если видишь потенциальные уязвимости (например, незащищённое соединение), укажи на это.
- Оцени производительность: не вызывает ли код лишних задержек.

## Flutter / ChatManager

- Сортировка чатов — через `ChatPositionInfo` / `updateChatPosition`, не по `lastMessageDate` вручную.
- `loadChats`, не устаревший паттерн «только getChats без positions».
- TDLib JSON парсится в `TdlibChatParser`, не дублируется в UI.
- `/api/*` vs `/ui/*` — не относится к RioGram (это Flutter-клиент); API-ответы TDLib обрабатываются в `ChatManager`.
- Нет `print()` — только `logging` при необходимости.
- Type hints везде в Dart.

## UI списка чатов

- Mobile / 720px / 840px breakpoints согласованы с `docs/CHATS.md`.
- Long-press и delete — с подтверждением для деструктивных действий.
- Hotkeys только через `ChatDesktopShortcuts`, не дублировать логику.

## Документация

При изменении §6.2 обновлять: `docs/CHATS.md`, `.cursor/context`, `TODO.md`.
