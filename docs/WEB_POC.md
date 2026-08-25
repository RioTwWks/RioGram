# Web-платформа RioGram — PoC §8.1

Дата: 2026-08-25  
Статус: исследование завершено, выбрана стратегия транспорта.

## Цель

Проверить, можно ли дать пользователям доступ к RioGram через браузер **без VPN/прокси на устройстве**, используя схему:

```
Пользователь (РФ) → RU VPS (Nginx + SSL) → SSH-туннель → EU (Web + WSS-прокси) → Telegram
```

---

## 1. Сборка Flutter Web

### 1.1. Основное приложение (`lib/main.dart`)

```bash
flutter build web --release
```

**Результат: сборка падает.**

Причина — прямой импорт `dart:ffi` и нативной `libtdjson`:

```
lib/core/tdlib/tdlib_client.dart:3:8: Error: Dart library 'dart:ffi' is not available on this platform.
lib/core/tdlib/tdlib_bindings.dart:1:8: Error: Dart library 'dart:ffi' is not available on this platform.
```

Wasm dry run также фиксирует те же блокеры. TDLib через FFI **не переносится** на Web без замены транспортного слоя (§8.2).

### 1.2. PoC-оболочка UI (`lib/main_web_poc.dart`)

Минимальный экран авторизации без TDLib — для проверки, что Flutter Web рендерит UI в стиле Telegram:

```bash
./scripts/build-web-poc.sh
# или:
flutter build web -t lib/main_web_poc.dart --release --no-wasm-dry-run
```

**Результат: сборка успешна** → `build/web/`.

Локальный просмотр:

```bash
cd build/web && python3 -m http.server 8765
# http://127.0.0.1:8765/
```

Проверено: HTTP 200, `index.html` и `flutter_bootstrap.js` отдаются корректно.

---

## 2. Несовместимости Web-платформы

### 2.1. Критичные (блокируют `main.dart`)

| Компонент | Файлы | Проблема | Решение (§8.2+) |
|-----------|-------|----------|-----------------|
| **TDLib FFI** | `tdlib_bindings.dart`, `tdlib_client.dart` | `dart:ffi`, `DynamicLibrary`, `libtdjson.so` недоступны в браузере | **tdweb** (TDLib → Emscripten/WASM + JS Worker) или **GramJS/teleproto** (чистый JS MTProto) |
| **dart:io** | 15+ файлов (`File`, `Directory`, `Platform`) | Недоступен на Web | `kIsWeb` + conditional imports, `path_provider` / IndexedDB |
| **DPI-патчи TDLib** | `td/` (ClientHello, DRS, фрагментация) | Браузер контролирует TLS/WebSocket — Fake TLS неприменим | Обход на уровне **WSS-транспорта** и инфраструктуры RU→EU, не клиентских патчей |
| **MTProto-прокси RioGram** | `proxy_manager.dart`, PhantomProxy/StealthGate | Браузер не умеет MTProto Fake TLS (`ee`-secret) | WSS reverse proxy к официальным `*.web.telegram.org` relay |

### 2.2. Файлы с `import 'dart:io'` (требуют адаптации)

```
lib/core/tdlib/tdlib_bindings.dart
lib/core/tdlib/tdlib_client.dart
lib/core/navigation/platform_navigation.dart
lib/core/proxy/system_proxy_detector.dart
lib/core/call/call_platform_service.dart
lib/core/media/media_cache_manager.dart
lib/core/media/media_file_saver.dart
lib/screens/stories/post_story_screen.dart
lib/screens/stories/story_viewer_screen.dart
lib/screens/chat/media_viewer_screen.dart
lib/widgets/message_bubble.dart
lib/widgets/audio_message_player.dart
lib/widgets/video_note_player.dart
lib/widgets/inline_video_player.dart
lib/widgets/media_album_grid.dart
lib/widgets/chat_avatar.dart
lib/widgets/sticker_file_image.dart
lib/widgets/call_device_picker_sheet.dart
```

### 2.3. Плагины pubspec.yaml

| Пакет | Web-поддержка | Заметки |
|-------|---------------|---------|
| `ffi` | ❌ | Только native |
| `record` | ❌ / ограничено | Запись голоса — web API или отключить |
| `flutter_contacts` | ❌ | Контакты через TDLib API |
| `local_auth` | ⚠️ | WebAuthn частично |
| `flutter_local_notifications` | ⚠️ | Push через Web Push API |
| `permission_handler` | ⚠️ | Частичная поддержка |
| `flutter_webrtc` | ✅ | VoIP возможен |
| `geolocator` | ✅ | С разрешениями браузера |
| `file_picker` | ✅ | |
| `video_player` | ✅ | |
| `audioplayers` | ✅ | |
| `shared_preferences` | ✅ | localStorage |
| `path_provider` | ✅ | IndexedDB backend |
| `webview_flutter` | ✅ | Mini Apps |

### 2.4. Официальный путь TDLib для браузера

В репозитории уже есть upstream-пример: `td/example/web/` → npm-пакет **tdweb** (Emscripten-сборка TDLib).

- Worker + WASM вместо FFI
- API: `TdClient.send()` / Promise, тот же JSON TDLib API
- Интеграция во Flutter Web — через **JS interop** (`dart:js_interop`) или iframe/host page

---

## 3. Исследование готовых решений

### 3.1. [tg-ws-proxy](https://github.com/Flowseal/tg-ws-proxy) (Flowseal)

| Параметр | Значение |
|----------|----------|
| Назначение | **Локальный SOCKS5-прокси** на машине пользователя |
| Транспорт | MTProto (SOCKS5) → WSS → `kws{N}.web.telegram.org` |
| Язык | Python (+ GUI), форки на Rust/Go |
| Для RioGram Web | ❌ Не server-side; клиент — Telegram Desktop, не браузер |

**Вывод:** полезен как референс алгоритма «MTProto → WebSocket frame», но **не деплоится как backend** для веб-клиента. Пользователь всё равно запускает локальный процесс.

### 3.2. [tg-proxy](https://github.com/AlexMelanFromRingo/tg-proxy) (Rust)

| Параметр | Значение |
|----------|----------|
| Назначение | Аналог tg-ws-proxy — **локальный SOCKS5 → WSS** |
| Особенности | Пул соединений, fallback на TCP, только официальные `kws*.web.telegram.org` |
| Для RioGram Web | ❌ Та же архитектура — desktop-side |

**Вывод:** качественная Rust-реализация bridge-алгоритма; можно заимствовать логику для **серверного** WSS-прокси в §8.3, но не использовать как есть.

### 3.3. [telegram-tt](https://github.com/Ajaxy/telegram-tt) (Telegram Web A)

| Параметр | Значение |
|----------|----------|
| Назначение | Официальный веб-клиент [web.telegram.org/a](https://web.telegram.org/a) |
| MTProto | **GramJS** (чистый JS/TS), не TDLib |
| Транспорт | Нативный browser WebSocket → `wss://*.web.telegram.org/apiws` |
| Прокси | В upstream **нет** UI прокси; форки (напр. PBhadoo/telegram-tt) добавляют **WebSocket Proxy Hook** + [TG-WS-API](https://github.com/CloudflareHackers/TG-WS-API) |

**Ключевой паттерн для блокировок:**

```
Browser (GramJS)
  → wss://your-domain.ru/pluto.web.telegram.org/apiws   # rewrite URL
  → WSS reverse proxy (EU, localhost)
  → wss://pluto.web.telegram.org/apiws                  # реальный Telegram DC
```

**Вывод:** эталон архитектуры веб-клиента с WSS-обходом. RioGram Web должен повторить **transports layer**, не обязательно UI.

### 3.4. [tdlib-obf](https://github.com/telemt/tdlib-obf)

| Параметр | Значение |
|----------|----------|
| Назначение | Форк TDLib с stealth shaping (DRS, IPT, TLS mimicry) |
| Активация | Только через **MTProto proxy** с `emulate_tls` |
| Партнёр | [telemt](https://github.com/telemt) MTProxy server |
| Для браузера | ❌ Патчи в C++ TCP/TLS стеке TDLib; браузер не использует этот путь |

**Вывод:** актуален для **native RioGram** (PhantomProxy/StealthGate), **не для Web**. Если выбрать tdweb — патчи `DPI_BYPASS` из `td/` нужно будет портировать отдельно (сложно) или полагаться на WSS-инфраструктуру.

---

## 4. Сравнение стратегий транспорта

| | **A. Прямой WSS reverse proxy** | **B. Через StealthGate/PhantomProxy** | **C. tg-ws-proxy на сервере** |
|---|--------------------------------|---------------------------------------|------------------------------|
| Схема | Browser WSS → RU Nginx → EU proxy → Telegram `*.web.telegram.org` | Browser WSS → RU → EU → Fake TLS MTProto proxy → Telegram | Browser → ??? → tg-ws-proxy (SOCKS5) |
| Совместимость с браузером | ✅ Нативный WebSocket | ⚠️ Нужен WSS→MTProto адаптер на EU | ❌ SOCKS5 не доступен из браузера |
| DPI на последней миле (РФ) | ✅ WSS/HTTPS к `.ru` домену | ✅ То же + MTProto stealth на EU→TG | ❌ Неверная модель |
| Переиспользование RioGram proxy | ❌ Отдельный WSS-слой | ✅ PhantomProxy/StealthGate на EU | ❌ |
| Сложность | Средняя | Высокая | Низкая, но **не работает** для Web |
| Референс | telegram-tt + TG-WS-API | Кастомная разработка | tg-ws-proxy (desktop only) |

---

## 5. Рекомендация: **Вариант A**

### Почему не B

StealthGate/PhantomProxy заточены под **Fake TLS MTProto** от native-клиента. Браузер уже устанавливает **настоящий TLS** к WSS endpoint. Добавление MTProto-proxy между EU и Telegram:

- не улучшает обход на стороне пользователя в РФ;
- добавляет лишний hop и latency;
- требует написания WSS→MTProto шлюза с нуля.

StealthGate остаётся актуален для **desktop/mobile RioGram**, не для Web.

### Почему не C

`tg-ws-proxy` слушает **SOCKS5** и рассчитан на Telegram Desktop. Браузерный клиент подключается к `wss://host/apiws`, а не к SOCKS5.

### Выбранная архитектура (A + инфра §8.4)

```
┌─────────────┐   WSS/443    ┌──────────────┐  SSH -R   ┌─────────────────────────┐
│   Browser   │ ──────────► │  RU VPS      │ ────────► │  EU VPS (127.0.0.1)     │
│ Flutter Web │  your.ru    │  Nginx+LE    │  tunnel   │  ├─ static (Flutter)    │
│  + tdweb    │             │  Upgrade: WS │           │  └─ WSS reverse proxy   │
└─────────────┘             └──────────────┘           └───────────┬─────────────┘
                                                                   │ WSS
                                                                   ▼
                                                    pluto/venus.web.telegram.org
```

**Клиент (§8.2):**

1. Заменить `TdlibClient` FFI на **tdweb** (сохранить TDLib API и весь Dart-код менеджеров) **или**
2. Отдельный JS-слой GramJS (как telegram-tt) — больше переписывания, меньше совместимости с текущим кодом.

**Рекомендация:** **tdweb** — минимальные изменения бизнес-логики, тот же `td_api.tl` JSON.

**WSS-прокси (§8.3):**

- Форк/адаптация [TG-WS-API](https://github.com/CloudflareHackers/TG-WS-API) (Workers) **или** self-hosted Rust/Go proxy по образцу tg-proxy (server mode)
- Слушает `127.0.0.1:5001` на EU, path `/apiws` или rewrite `/{dc}.web.telegram.org/apiws`
- Nginx на RU проксирует `location /apiws` через SSH-туннель

**Настройка в UI:** поле `wss://your-domain.ru/` (аналог §8.2).

---

## 6. Следующие шаги (§8.2–8.8)

| § | Задача |
|---|--------|
| 8.2 | `TdlibClientWeb` через tdweb + JS interop; stub для `dart:io` файлов |
| 8.3 | WSS reverse proxy на EU (PoC с `wscat`) |
| 8.4 | SSH-туннель + Nginx WSS (autossh, Let's Encrypt) |
| 8.5 | CI: `flutter build web` для PoC → полный билд после 8.2 |
| 8.6 | E2E: авторизация через WSS из браузера в РФ |
| 8.8 | Перенести этот документ в `docs/WEB.md` после реализации |

---

## 7. Команды PoC

```bash
# Полное приложение (ожидаемо падает)
flutter build web --release

# UI PoC (работает)
./scripts/build-web-poc.sh

# Добавить web-платформу (уже выполнено)
flutter create . --platforms=web
```

---

## Ссылки

- [tdweb / TDLib Web example](td/example/web/README.md)
- [PROXY.md](PROXY.md) — PhantomProxy / StealthGate (native)
- [TG-WS-API](https://github.com/CloudflareHackers/TG-WS-API) — Cloudflare Workers WSS proxy
- [seriyps/mtproto_proxy#90](https://github.com/seriyps/mtproto_proxy/issues/90) — WebSocket ≠ MTProto proxy protocol
