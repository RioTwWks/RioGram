---
command: Запустить клиент в отладочном режиме
---

# Запуск

1. Заполнить `.env` (`TELEGRAM_API_ID`, `TELEGRAM_API_HASH`, прокси) — [docs/QUICKSTART.md](../../docs/QUICKSTART.md)
2. Собрать TDLib (если ещё не собран):
   ```bash
   CC=gcc CXX=g++ TD_ENABLE_LTO=OFF ./scripts/build-tdlib.sh
   ./scripts/copy-tdlib.sh linux   # windows / macos / android / ios
   ```
3. Запуск:
   ```bash
   flutter pub get
   flutter run -d linux
   ```

Прокси-серверы (PhantomProxy, StealthGate) должны быть доступны для полного теста подключения.

## Проверка UI

| Платформа | Что проверить |
|-----------|----------------|
| Desktop ≥840px | 3 колонки: папки \| чаты \| переписка |
| Desktop 720–839px | 2 колонки + вкладки папок |
| Mobile | Список → tap → переписка |

**Горячие клавиши (desktop):** `Ctrl/Cmd+F` или `K` — поиск; `N` — новый чат; `↑/↓` — навигация по чатам.

## Настройки RioGram

- Прокси: Settings → Proxy
- Плагины: Settings → Plugins ([docs/PLUGINS.md](../../docs/PLUGINS.md))
- UI-кастомизация §7.3, безопасность §7.4 — в разделе настроек

Документация: [docs/CHATS.md](../../docs/CHATS.md) · Сборка TDLib: [@build-tdlib](build-tdlib.md)
