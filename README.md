# RioGram — Censorship‑Resistant Telegram Client

**RioGram** is a cross‑platform Telegram client built with Flutter and a heavily patched TDLib. It is designed to stay online even under aggressive Deep Packet Inspection (DPI) by:
- **Randomizing TLS ClientHello** (mimicking Chrome, Firefox, etc.)
- **Fragmenting** the first handshake packets
- **Dynamically varying** record sizes
- **Automatically switching** between your own proxies (PhantomProxy and StealthGate) with failover logic

Supports Windows, macOS, Linux, Android, and iOS.

## MVP Stage 1 (текущий)

- Flutter-проект с архитектурой `lib/core`, `lib/screens`, `lib/models`
- FFI-обёртка `TdlibClient` над `libtdjson`
- Авторизация: телефон → код → 2FA
- `ProxyManager` с failover PhantomProxy → StealthGate

## Быстрый старт

```bash
cp .env.example .env
# Заполните TELEGRAM_API_ID, TELEGRAM_API_HASH и адреса прокси

flutter pub get
flutter run -d linux   # или windows, macos, android
```

> **Важно:** для работы нужна собранная `libtdjson` (см. `.cursor/commands/build-tdlib.md`).

## Структура

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── config/app_config.dart
│   ├── tdlib/tdlib_client.dart
│   ├── auth/auth_manager.dart
│   └── proxy/proxy_manager.dart
├── screens/
│   ├── auth/          # phone, code, password
│   └── chats/         # список чатов
├── models/
└── widgets/
```

## Лицензия

GPLv3 with OpenSSL exception.
