# Установка RioGram

Инструкция для пользователей готовых сборок из [GitHub Releases](https://github.com/RioTwWks/RioGram/releases).

> Сборки содержат вшитый `.env` с `api_id`/`api_hash` автора релиза. Для своих ключей — соберите клиент самостоятельно ([BUILD.md](BUILD.md)).

## Linux

1. Скачайте `RioGram-X.Y.Z-linux-x64.tar.gz`
2. Распакуйте:
   ```bash
   mkdir -p ~/Apps/RioGram && tar -xzf RioGram-*.tar.gz -C ~/Apps/RioGram
   ```
3. Запустите:
   ```bash
   ~/Apps/RioGram/riogram
   ```

При необходимости создайте `.desktop`-файл для меню приложений.

**Зависимости:** GTK 3 (обычно уже установлен в Ubuntu/Fedora).

---

## Windows

1. Скачайте `RioGram-X.Y.Z-windows-x64.zip`
2. Распакуйте в `C:\Program Files\RioGram\` (или любую папку)
3. Запустите `riogram.exe`

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

---

## iOS

Сборка `ios-unsigned.zip` **не устанавливается** на iPhone без подписи разработчика.

Варианты:
- Собрать самостоятельно в Xcode с Apple Developer аккаунтом
- Дождаться подписанной сборки в App Store (после MVP)

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
