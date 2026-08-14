---
command: Запустить клиент в отладочном режиме
---

# Запуск

1. Убедиться, что прокси-серверы запущены (PhantomProxy и StealthGate).
2. Собрать TDLib (если ещё не собран):
   ```bash
   ./scripts/build-tdlib.sh
   ./scripts/copy-tdlib.sh linux   # или windows / macos
   ```
3. Из корня проекта:
   ```bash
   flutter pub get
   flutter run -d linux    # windows / macos / android / ios
   ```
4. Заполните `.env` (`TELEGRAM_API_ID`, `TELEGRAM_API_HASH`, прокси) — см. `docs/QUICKSTART.md`.

## Проверка §6.2 (список чатов)

После авторизации:

| Платформа | Что проверить |
|-----------|----------------|
| **Desktop** (окно ≥840px) | 3 колонки: папки \| чаты \| переписка |
| **Desktop** (720–839px) | 2 колонки + горизонтальные вкладки папок |
| **Mobile** | Список → tap → экран переписки |

**Горячие клавиши (desktop):**

- `Ctrl/Cmd+F` или `Ctrl/Cmd+K` — фокус на поиск
- `Ctrl/Cmd+N` — новый чат
- `Ctrl/Cmd+↑/↓` — предыдущий / следующий чат

Документация: `docs/CHATS.md`.
