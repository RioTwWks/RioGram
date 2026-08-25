# Web-транспорт RioGram (§8.2)

Документ описывает клиентский WSS-транспорт для браузерной версии RioGram.

См. также: [WEB_POC.md](WEB_POC.md) (§8.1), [PROXY.md](PROXY.md) (native MTProto).

---

## Архитектура

```
┌──────────────────────────────────────────────────────────────┐
│ Browser                                                       │
│  Flutter Web (Dart)                                            │
│    TdlibClientWeb ──JS──► RioGramTdlib ──► tdweb (WASM)      │
│                              ▲                                │
│  WebProxyManager ────────────┤                                │
│    WssProxyConfig            │                                │
│                              ▼                                │
│  wss_proxy_hook.js: window.WebSocket → rewrite URL           │
└──────────────────────────────┬───────────────────────────────┘
                               │ WSS/443
                               ▼
                    RU Nginx → SSH → EU reverse proxy (§8.3)
                               ▼
                    venus/pluto.web.telegram.org/apiws
```

### Слои

| Слой | Файлы | Назначение |
|------|-------|------------|
| **WSS Hook** | `web/js/wss_proxy_hook.js` | Перехват `WebSocket`, rewrite Telegram URL |
| **TDLib Bridge** | `web/js/tdlib_bridge.js` | JS API `RioGramTdlib` для tdweb |
| **Dart bridge** | `lib/core/tdlib/web/tdlib_js_bridge.dart` | Dart ↔ JS interop |
| **URL rewriter** | `lib/core/tdlib/web/wss_url_rewriter.dart` | Тестируемая логика rewrite |
| **Web client** | `lib/core/tdlib/tdlib_client_web.dart` | TdlibClient без FFI |
| **Proxy manager** | `lib/core/proxy/web_proxy_manager.dart` | Настройки, мониторинг, reconnect |
| **UI** | `lib/widgets/web_socket_proxy_settings.dart` | Экран настроек WSS |

---

## Алгоритм rewrite URL

Совместим с [telegram-tt Proxy Hook](https://github.com/Pbhadoo/telegram-tt) и [TG-WS-API](https://github.com/CloudflareHackers/TG-WS-API):

```
wss://venus.web.telegram.org/apiws
  → wss://your-domain.ru/venus.web.telegram.org/apiws
```

Настройки хранятся в `SharedPreferences` (Dart) и дублируются в `localStorage` (JS hook).

---

## Подключение tdweb

TDLib для браузера собирается через Emscripten (upstream: `td/example/web/`).

### Требования

| Компонент | Версия |
|-----------|--------|
| emsdk | **3.1.1** (`emcc --version`; скрипт проверяет `--version`, не `--check`) |
| cmake, gperf, perl, php-cli | см. `scripts/install-linux-build-deps.sh` |
| node/npm | для webpack (`build-tdweb.sh`) |

> **Примечание:** шаг `build-tdlib.sh` генерирует исходники через системный cmake.
> Если `c++` — clang без libstdc++, задайте `CC=gcc CXX=g++` (скрипт `build-tdweb.sh` делает это автоматически).

```bash
# Установка emsdk (один раз)
git clone https://github.com/emscripten-core/emsdk.git ~/emsdk
cd ~/emsdk && ./emsdk install 3.1.1 && ./emsdk activate 3.1.1
source ~/emsdk/emsdk_env.sh
```

### Сборка

```bash
./scripts/build-tdweb.sh   # openssl → tdlib wasm → webpack (~30+ мин)
./scripts/copy-tdweb.sh    # td/example/web/tdweb/dist → web/tdweb/
```

Скрипт `build-tdweb.sh` вызывает upstream-цепочку:

1. `build-openssl.sh` — OpenSSL 1.1.0l для Emscripten
2. `build-tdlib.sh` — `td_wasm.js` + `td_wasm.wasm`
3. `copy-tdlib.sh` → `tdweb/src/prebuilt/release/`
4. `build-tdweb.sh` — webpack → `tdweb/dist/tdweb.js`

### Подключение в index.html

```html
<script src="js/wss_proxy_hook.js"></script>
<script src="tdweb/tdweb.js"></script>
<script src="js/tdlib_bridge.js"></script>
```

Webpack экспортирует UMD-библиотеку `window.tdweb` (default = `TdClient`).
`tdlib_bridge.js` резолвит класс через `window.tdweb.default || window.tdweb`.

Артефакты `web/tdweb/` в `.gitignore` — собираются локально или в CI.

Без tdweb приложение покажет ошибку при инициализации TDLib, но **WSS hook и настройки работают** (можно тестировать rewrite в UI).

---

## Настройка WSS-прокси

1. Откройте **Настройки → Прокси** (Web)
2. Включите **WSS-прокси**
3. Укажите адрес: `wss://your-domain.ru` (или `https://...` — нормализуется автоматически)
4. Нажмите **Сохранить адрес** — в snackbar покажется preview rewrite

### Автопереподключение

`WebProxyManager` отслеживает статус транспорта (`connecting` / `connected` / `failed`) и при обрыве:

1. Вызывает `setNetworkType(none)` → пауза 300 ms → `setNetworkType(other)`
2. До `maxReconnectAttempts` (по умолчанию 5) с нарастающей задержкой

---

## API (JS)

### `window.RioGramWssProxy`

```javascript
RioGramWssProxy.writeConfig({
  enabled: true,
  url: 'wss://your-domain.ru',
  autoReconnect: true,
  maxReconnectAttempts: 5,
  reconnectDelayMs: 2000,
});
RioGramWssProxy.rewriteUrl('wss://venus.web.telegram.org/apiws');
RioGramWssProxy.getTransportStatus();
```

### `window.RioGramTdlib`

```javascript
RioGramTdlib.create({ instanceName: 'riogram', onUpdate: (u) => {} });
RioGramTdlib.send({ '@type': 'getMe' });
RioGramTdlib.close();
```

---

## Сборка и тест

```bash
# Unit-тесты транспорта
flutter test test/wss_url_rewriter_test.dart

# Web PoC UI (без TDLib)
./scripts/build-web-poc.sh

# Полный Web (после tdweb)
./scripts/build-web.sh
```

### Локальная проверка hook

```bash
cd build/web && python3 -m http.server 8765
# DevTools → Application → Local Storage → riogram_wss_proxy_config
# DevTools → Network → WS — URL должен содержать ваш proxy host
```

---

## Отличия от native ProxyManager

| | Native (§3) | Web (§8.2) |
|---|-------------|------------|
| Протокол | MTProto Fake TLS (`addProxy`) | Browser WSS rewrite |
| Прокси | PhantomProxy / StealthGate | WSS reverse proxy |
| TDLib | FFI `libtdjson` | tdweb WASM |
| DPI-патчи | `DPI_BYPASS` в td/ | Не применимы (браузерный TLS) |

---

## Следующие шаги

- **§8.3** — server-side WSS reverse proxy на EU — см. [WEB_PROXY.md](WEB_PROXY.md)
- **§8.4** — RU Nginx + SSH-туннель
- **§8.5** — CI `flutter build web` для production — см. [WEB.md](WEB.md)
