# PLAN.md — План разработки RioGram

> **Статус (август 2026):** MVP в основном реализован (этапы 1–4 и большая часть 5). **§6.2** (список чатов и организация) закрыт. Инфраструктура прокси и полевые DPI-тесты — в процессе.  
> Детальный чеклист — [TODO.md](TODO.md). Документация — [docs/](docs/), список чатов — [docs/CHATS.md](docs/CHATS.md).

---

## 1. Цель

Создать кросс-платформенный клиент Telegram (**RioGram**) на Flutter с модифицированным TDLib, способный обходить блокировки РКН:

- рандомизированный TLS ClientHello (Fake TLS)
- фрагментация и маскировка трафика
- собственные прокси (PhantomProxy, StealthGate) с автоматическим failover

**Продуктовая стратегия в три слоя:**

| Слой | Раздел TODO | Суть |
|------|-------------|------|
| **MVP** | §0–§5 | Авторизация, чаты, базовый UI, DPI-патчи, прокси, сборка |
| **Паритет с Telegram** | §6 + §9 | Функционал и визуал как у официального клиента **до Liquid Glass** |
| **Уникальность RioGram** | §7 + §8 | Ghost Mode, анти-отзыв, стелс-DPI, Web-платформа |

Приложение даёт контроль над сетевой логикой и, поверх классического вида Telegram, — расширенную кастомизацию (§7.3).

---

## 2. Архитектура

```
┌─────────────────────────────────────────────────────┐
│                Flutter UI (Dart)                    │
│  lib/screens, lib/widgets, lib/core                 │
│  Provider (AuthManager, ChatManager, ProxyManager)  │
└─────────────────────┬───────────────────────────────┘
                      │ FFI (dart:ffi → libtdjson)
┌─────────────────────▼───────────────────────────────┐
│              TDLib (форк в td/)                      │
│  Telegram API + патчи DPI_BYPASS:                   │
│    • профили ClientHello (Chrome/Firefox/Yandex/…)  │
│    • фрагментация первого пакета (DpiBypass.cpp)    │
│    • DRS — размеры TLS-записей (TcpTransport.cpp)   │
└─────────────────────┬───────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────┐
│     Прокси (VPS)                                     │
│  PhantomProxy (РФ, основной)                        │
│  StealthGate (РФ front + EU back, резервный)        │
└─────────────────────────────────────────────────────┘
```

Ключевые модули приложения:

| Модуль | Путь | Назначение |
|--------|------|------------|
| TDLib FFI | `lib/core/tdlib/` | `TdlibClient`, биндинги |
| Авторизация | `lib/core/auth/` | Phone → code → 2FA |
| Чаты | `lib/core/chat/` | Список, переписка, медиа |
| Прокси | `lib/core/proxy/` | Failover, ping, настройки |
| Темы | `lib/core/theme/` | Светлая/тёмная, акцент (→ §9) |

Патчи TDLib: [docs/TDLIB_PATCHES.md](docs/TDLIB_PATCHES.md). Прокси: [docs/PROXY.md](docs/PROXY.md).

---

## 3. Этапы разработки

Соответствие этапов PLAN и разделов TODO:

| Этап PLAN | TODO | Статус |
|-----------|------|--------|
| 0. Инфраструктура | §0 | Частично (~прокси, Docker) |
| 1. Flutter + TDLib | §1 | ✅ В основном готово |
| 2. DPI-патчи | §2 | ✅ Код готов; полевые тесты — нет |
| 3. Прокси | §3 | ✅ Готово |
| 4. UI (MVP) | §4 | ~ Остались video inline, voice, кэш |
| 5. Сборка и релиз | §5 | ~ CI/release готовы; бета, иконки — нет |
| 6. Паритет функционала | §6 | ~ §6.2 готово; остальное — в работе |
| 7. Дизайн «классический TG» | §9 | 🔜 Параллельно с §6 |
| 8. Уникальные фичи | §7 | 🔜 После паритета |
| 9. Web-платформа | §8 | 🔜 Отдельный трек |

---

### Этап 0: Инфраструктура (TODO §0)

| Задача | Статус |
|--------|--------|
| API-ключи my.telegram.org | ✅ |
| VPS РФ (×2) + EU | ✅ |
| PhantomProxy, StealthGate (Front/Back) | ~ |
| Проверка через Telegram Desktop | ~ |
| Flutter SDK ≥3.22, `scripts/build-tdlib.sh` | ✅ |

### Этап 1: Flutter + TDLib (TODO §1)

| Задача | Статус |
|--------|--------|
| Проект `com.riotwwks.riogram`, структура `lib/` | ✅ |
| Зависимости: `provider`, `ffi`, `flutter_dotenv`, … | ✅ |
| `TdlibClient`: init, send, updates | ✅ |
| Авторизация: phone → code → 2FA | ✅ |
| Список чатов, навигация в переписку | ✅ |
| Сохранение сессии после перезапуска | ⬜ |

**Итог:** клиент авторизуется и показывает чаты.

### Этап 2: Обход DPI (TODO §2)

| Задача | Статус |
|--------|--------|
| Форк TDLib в `td/` | ✅ |
| 4 профиля ClientHello, фрагментация, DRS | ✅ |
| Скрипты сборки: Linux, Win, macOS, Android, iOS | ✅ |
| `copy-tdlib.sh` → Flutter-проект | ✅ |
| Полевые тесты на сетях провайдеров | ⬜ |

**Итог:** патчи в коде; стабильность на реальных сетях — не подтверждена.

### Этап 3: Прокси (TODO §3)

| Задача | Статус |
|--------|--------|
| `addProxy` (MTProto), PhantomProxy + StealthGate | ✅ |
| `pingProxy`, failover каждые 30 с | ✅ |
| UI настроек, индикатор статуса | ✅ |

**Итог:** автоматическое переключение прокси работает.

### Этап 4: UI MVP (TODO §4)

| Задача | Статус |
|--------|--------|
| Светлая/тёмная тема, акцентный цвет | ✅ |
| Чаты, переписка, настройки; master-detail | ✅ |
| Текст, фото, файлы; «печатает…» | ✅ |
| Уведомления (`flutter_local_notifications`) | ✅ |
| Inline-видео, голосовые, кэш медиа | ⬜ |

**Итог:** базовый мессенджер; медиа-полировка не завершена.

> Целевой визуальный стиль — не произвольная тема MVP, а **классический Telegram** ([TODO §9](TODO.md#9-дизайн-в-стиле-классического-telegram-до-liquid-glass)).

### Этап 5: Сборка и релиз (TODO §5)

| Задача | Статус |
|--------|--------|
| CI/CD, release workflow (все платформы) | ✅ |
| [docs/BUILD.md](docs/BUILD.md), [docs/INSTALL.md](docs/INSTALL.md), [docs/SIGNING.md](docs/SIGNING.md) | ✅ |
| Юнит-тесты (proxy, models, theme) | ✅ |
| Mock TDLib: auth, failover | ⬜ |
| Бета-тестирование, иконки приложения | ⬜ |

**Итог:** пайплайн сборки готов; до публичного релиза — полевые тесты и полировка.

---

## 4. После MVP: дорожная карта

Краткая карта; детали — в [TODO.md](TODO.md).

### Фаза A — Закрытие MVP
- Дожать §4.3 (video, voice, cache), §1.4 (сессия), §2.7, §5.4–5.5
- Критерии из §6 ниже — все `[x]`

### Фаза B — Паритет с Telegram (§6 + §9)
**Готово:** §6.2 — список чатов (pin, архив, папки, поиск, desktop 3-column) — см. [docs/CHATS.md](docs/CHATS.md).

**Функционал (§6):** редактирование/удаление, группы и каналы, стикеры, контакты, поиск, настройки приватности, VoIP, мультиаккаунт, боты, секретные чаты, stories — по фазам A→E в TODO.

**Дизайн (§9):** токены (`#3390EC`, плоские пузыри, Roboto/SF Pro), список чатов и переписка как Telegram Desktop / mobile **до Liquid Glass** — без blur и frosted glass.

### Фаза C — Уникальность RioGram (§7)
- Призрачный режим, анти-отзыв, продвинутый стелс-DPI
- Кастомизация **сверх** классического вида (§7.3)
- Синхронизация форка TDLib с upstream (§7.7)

### Фаза D — Web (§8)
- Flutter Web + WSS-транспорт, схема RU Frontend → EU Backend
- Обход блокировок в браузере без VPN на устройстве

---

## 5. Ресурсы и инструменты

### Собственные репозитории
- [RioGram](https://github.com/RioTwWks/RioGram) — этот проект
- [PhantomProxy](https://github.com/RioTwWks/PhantomProxy) — MTProto-прокси (Go)
- [StealthGate](https://github.com/RioTwWks/StealthGate) — стелс-прокси (Rust)

### Референсы TDLib / DPI
- [ZaStoGram_desktop](https://github.com/youtubediscord/ZaStoGram_desktop) — Fake TLS, фрагментация
- [telemt/tdlib-obf](https://github.com/telemt/tdlib-obf) — обфускация трафика
- [tdlib/td](https://github.com/tdlib/td) — upstream для merge

### Flutter-клиенты
- [Mithka](https://github.com/iebb/mithka) — Flutter + TDLib
- [telega2](https://github.com/festeh/telega2) — FFI-интеграция

### Стек RioGram (фактический)
- **State:** `provider`
- **TDLib:** ручной FFI (`lib/core/tdlib/`), не `tdlib_library`
- **Конфиг:** `flutter_dotenv`, `.env`
- **Медиа/файлы:** `file_picker`, `path_provider`
- **Уведомления:** `flutter_local_notifications`
- **Настройки:** `shared_preferences`

Сборка TDLib: [tdlib.github.io/td/build.html](https://tdlib.github.io/td/build.html), скрипты в `scripts/`.

---

## 6. Критерии готовности MVP

- [x] Авторизация по номеру телефона (phone → code → 2FA) на всех платформах.
- [x] Список чатов загружается, открывается переписка.
- [x] Текстовые сообщения отправляются и принимаются.
- [x] Фото и файлы — отправка и отображение.
- [x] Прокси PhantomProxy / StealthGate подключены, failover реализован.
- [x] Настраиваемая тема, экран настроек, индикатор прокси.
- [x] CI/CD и release workflow для Linux, Windows, macOS, Android, iOS.
- [ ] Сессия сохраняется после перезапуска приложения.
- [ ] Полевое подтверждение DPI-обхода на сетях провайдеров.
- [ ] Inline-видео и голосовые сообщения (минимум для «ежедневного» использования).
- [ ] Бета-тест и иконки приложения.

**MVP считается закрытым**, когда все пункты отмечены и пользователь может стабильно переписываться через RioGram в РФ без VPN на устройстве.

---

## 7. Прогресс паритета с Telegram (§6)

См. [TODO.md](TODO.md) §6 и §9.

| Подраздел | Статус | Документация |
|-----------|--------|--------------|
| **§6.2** Список чатов и организация | ✅ | [docs/CHATS.md](docs/CHATS.md) |
| §6.3 Сообщения (edit, reply, forward) | ⬜ | — |
| §6.4 Медиа, стикеры, GIF | ⬜ | — |
| §6.5 Группы и каналы | ⬜ | — |
| §6.6 Звонки и геолокация | ⬜ | — |
| §9 Классический дизайн (до Liquid Glass) | ⬜ | — |

---

## 8. Риски и смягчение

| Риск | Смягчение |
|------|-----------|
| Устаревание DPI-патчей при обновлении MTProto | Форк `td/`, процесс merge upstream ([TODO §7.7](TODO.md)) |
| Блокировка IP VPS | Несколько VPS, Front/Back StealthGate, быстрая замена Front |
| Сложность сборки TDLib на всех платформах | GitHub Actions, `scripts/build-tdlib-*.sh` |
| Регрессия обхода после merge TDLib | Чеклист `TDLIB_PATCHES.md`, тесты подключения |
| Утечка `api_hash` | Только `.env`, см. [docs/SECRETS.md](docs/SECRETS.md) |
| Юридические риски копирования UI Telegram | Свой бренд RioGram; §9 — «родство», не пиксель-копия логотипа |

---

## 9. Навигация по документации

| Документ | Назначение |
|----------|------------|
| [TODO.md](TODO.md) | Детальный чеклист по всем фазам |
| [docs/CHATS.md](docs/CHATS.md) | Список чатов: pin, архив, папки, hotkeys |
| [docs/QUICKSTART.md](docs/QUICKSTART.md) | Быстрый старт разработчика |
| [docs/BUILD.md](docs/BUILD.md) | Сборка приложения и TDLib |
| [docs/INSTALL.md](docs/INSTALL.md) | Установка для пользователей |
| [docs/PROXY.md](docs/PROXY.md) | Настройка PhantomProxy / StealthGate |
| [docs/TDLIB_PATCHES.md](docs/TDLIB_PATCHES.md) | Описание DPI-патчей |
