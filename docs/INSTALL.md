# Установка RioGram

Инструкция для пользователей готовых сборок из [GitHub Releases](https://github.com/RioTwWks/RioGram/releases).

> Сборки содержат вшитый `.env` с `api_id`/`api_hash` автора релиза. Для своих ключей — соберите клиент самостоятельно ([BUILD.md](BUILD.md)).

## Linux

1. Скачайте `RioGram-X.Y.Z-linux-x64.tar.gz`
2. Распакуйте (создаётся каталог `RioGram-X.Y.Z-linux-x64/`):
   ```bash
   tar -xzf RioGram-*.tar.gz
   ```
   Если используете `-C <каталог>`, **сначала создайте** его: `mkdir -p riogram`
3. Запустите:
   ```bash
   ./RioGram-*/riogram
   ```

**Требования:** glibc x86_64, GTK 3, **GLib ≥ 2.72** (Ubuntu 22.04+, Astra Linux 1.8+, Debian 12+).  
Сборки с `ubuntu-latest` (GLib 2.80+) не запустятся на дистрибутивах со старым GLib — нужен релиз, собранный на Ubuntu 22.04.

Проверка GLib: `pkg-config --modversion glib-2.0`

---

## Windows

1. Скачайте `RioGram-X.Y.Z-windows-x64.zip`
2. Распакуйте в любую папку (например `C:\RioGram\`)
3. Запустите `riogram.exe` **из этой папки** (рядом должны лежать `tdjson.dll`, `libssl-3-x64.dll`, `libcrypto-3-x64.dll`, `zlib1.dll`)

При предупреждении SmartScreen: «Подробнее» → «Выполнить в любом случае» (сборка пока без код-подписи).

---

## macOS

1. Скачайте `RioGram-X.Y.Z-macos-arm64.zip`
2. Распакуйте и перетащите `riogram.app` в **Программы**
3. При первом запуске: **Системные настройки → Конфиденциальность** → разрешить запуск

Сборка для Apple Silicon (M1/M2/M3). Intel Mac — соберите из исходников.

---

## Android

1. Скачайте `RioGram-X.Y.Z-android-arm64.apk` (или `armv7` для старых устройств)
2. Разрешите установку из неизвестных источников
3. Установите APK

Для Google Play используется `.aab` — только для публикации в магазин.

> **Важно:** в релизных APK прокси и API-ключи **вшиты при сборке**. Для работы нужен доступ в интернет (разрешение `INTERNET` в манифесте) и запущенный PhantomProxy/StealthGate на VPS из `.env`. Свои прокси — только через пересборку ([BUILD.md](BUILD.md)).

---

## iOS

1. **Подписанный IPA** (`RioGram-X.Y.Z-ios.ipa`) — если настроены secrets в CI; загрузка через TestFlight / App Store
2. **Unsigned zip** — fallback без secrets; установка только после ручной подписи в Xcode

Подробнее: [SIGNING.md](SIGNING.md)

---

## Первый запуск

1. Убедитесь, что **PhantomProxy** и **StealthGate** запущены на ваших VPS
2. Войдите по номеру телефона (как в обычном Telegram)
3. **Настройки** → проверьте статус прокси (зелёный индикатор)

Прокси настраиваются при сборке через `.env` / GitHub Secrets. Если прокси не заданы — клиент подключается напрямую (может не работать в РФ).

---

## Обновление

Скачайте новый релиз с GitHub и замените файлы. База TDLib (чаты, авторизация) хранится локально в каталоге данных приложения и сохраняется между обновлениями.

| Платформа | Каталог данных (примерно) |
|-----------|---------------------------|
| Linux | `~/.local/share/com.riotwwks.riogram/` |
| Windows | `%APPDATA%\com.riotwwks\riogram\` |
| macOS | `~/Library/Application Support/com.riotwwks.riogram/` |

---

## Сборка из исходников

См. [BUILD.md](BUILD.md) и [QUICKSTART.md](QUICKSTART.md).
