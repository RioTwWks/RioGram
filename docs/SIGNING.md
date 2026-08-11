# Подпись мобильных сборок RioGram

Руководство по release-подписи **Android** (APK/AAB) и **iOS** (IPA) для локальной разработки и GitHub Actions.

| Платформа | Файл конфигурации | CI secrets |
|-----------|---------------------|------------|
| Android | `android/key.properties` + keystore `.jks` | `ANDROID_*` |
| iOS | `ios/Flutter/Signing.xcconfig` + `ios/ExportOptions.plist` | `IOS_*`, `KEYCHAIN_PASSWORD` |

Без настроенных secrets CI собирает **Android с debug-подписью** и **iOS без подписи** (как раньше). Это удобно для тестов, но не подходит для публикации в магазинах.

---

## Содержание

1. [Общие принципы](#общие-принципы)
2. [Android](#android)
3. [iOS](#ios)
4. [GitHub Actions](#github-actions)
5. [Безопасность](#безопасность)
6. [Устранение неполадок](#устранение-неполадок)

---

## Общие принципы

### Что такое подпись

Подпись криптографически связывает приложение с **ключом разработчика**. Магазины (Google Play, App Store) и ОС проверяют подпись при установке и обновлении:

- **Android:** один keystore на всё время жизни приложения в Play Store. Потеря keystore = невозможность выпускать обновления под тем же `applicationId`.
- **iOS:** сертификат Apple + provisioning profile. Сертификаты истекают (обычно 1 год), их нужно перевыпускать.

### Что не коммитить в git

| Файл | Причина |
|------|---------|
| `android/key.properties` | пароли |
| `android/app/*.jks`, `*.jks` | приватный ключ |
| `ios/Flutter/Signing.xcconfig` | Team ID, profile |
| `ios/ExportOptions.plist` | генерируется из secrets |

Шаблоны: `android/key.properties.example`, `ios/ExportOptions.plist.example`.

### Скрипты проекта

| Скрипт | Назначение |
|--------|------------|
| `scripts/setup-android-signing.sh` | Декодирует keystore из `ANDROID_KEYSTORE_BASE64`, создаёт `key.properties` |
| `scripts/setup-ios-signing.sh` | Импортирует `.p12`, profile, keychain, генерирует `Signing.xcconfig` и `ExportOptions.plist` |
| `scripts/build-release.sh` | Вызывает setup-скрипты, если заданы переменные окружения |

---

## Android

### 1. Создание release keystore

Выполните **один раз** на защищённой машине. Сохраните keystore и пароли в менеджере паролей (1Password, Bitwarden и т.д.).

```bash
keytool -genkey -v \
  -keystore ~/riogram-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias riogram
```

Параметры:

| Параметр | Рекомендация |
|----------|--------------|
| `-alias` | `riogram` (должен совпадать с `ANDROID_KEY_ALIAS` в CI) |
| `-validity` | 10000 дней (~27 лет) |
| CN/OU | можно указать название проекта |

**Важно:** сделайте резервную копию `riogram-release.jks` вне репозитория. Google Play **не примет** новый keystore для уже опубликованного приложения.

### 2. Локальная подпись

1. Скопируйте keystore в проект (не коммитьте):

   ```bash
   cp ~/riogram-release.jks android/app/riogram-release.jks
   ```

2. Создайте `android/key.properties` из шаблона:

   ```bash
   cp android/key.properties.example android/key.properties
   ```

3. Заполните `android/key.properties`:

   ```properties
   storePassword=ваш_пароль_хранилища
   keyPassword=ваш_пароль_ключа
   keyAlias=riogram
   storeFile=riogram-release.jks
   ```

   Путь `storeFile` — относительно каталога `android/app/` или абсолютный.

4. Соберите release:

   ```bash
   ./scripts/build-tdlib-android.sh
   flutter build apk --release --split-per-abi
   flutter build appbundle --release
   ```

Gradle читает конфигурацию в `android/app/build.gradle.kts`: при наличии `key.properties` используется release signing, иначе — debug.

### 3. Проверка подписи APK

```bash
# Список сертификатов в APK
apksigner verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Или через keytool (старый способ)
unzip -p build/app/outputs/flutter-apk/app-arm64-v8a-release.apk META-INF/CERT.RSA | keytool -printcert
```

Debug-подпись содержит `CN=Android Debug` — такой APK нельзя загрузить в Play Console как production.

### 4. Публикация в Google Play

1. Соберите **AAB** (обязателен для новых приложений):

   ```bash
   flutter build appbundle --release
   ```

2. Загрузите `build/app/outputs/bundle/release/app-release.aab` в [Google Play Console](https://play.google.com/console).

3. При первой загрузке Play может предложить **Play App Signing** — Google хранит ключ подписи дистрибуции, вы загружаете AAB, подписанный upload-ключом. Рекомендуется включить.

### 5. Подготовка secrets для CI

Закодируйте keystore в base64 (без переносов строк):

```bash
base64 -w0 ~/riogram-release.jks   # Linux
base64 -i ~/riogram-release.jks    # macOS
```

Добавьте в GitHub → **Settings → Secrets and variables → Actions**:

| Secret | Значение |
|--------|----------|
| `ANDROID_KEYSTORE_BASE64` | вывод `base64` |
| `ANDROID_KEYSTORE_PASSWORD` | пароль хранилища |
| `ANDROID_KEY_PASSWORD` | пароль ключа (если совпадает — можно тот же) |
| `ANDROID_KEY_ALIAS` | `riogram` |

При следующем Release workflow job `build-android` вызовет `setup-android-signing.sh` и соберёт подписанные APK/AAB.

---

## iOS

### Требования

- **macOS** с Xcode
- Участие в [Apple Developer Program](https://developer.apple.com/programs/) ($99/год)
- Bundle ID: `com.riotwwks.riogram` (уже в проекте)

### 1. Сертификаты и профили в Apple Developer

1. Откройте [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources).

2. **App ID** (если ещё нет):
   - Identifiers → **+** → App IDs → `com.riotwwks.riogram`

3. **Сертификат Distribution**:
   - Certificates → **+** → **Apple Distribution**
   - Создайте CSR в Keychain Access (Certificate Assistant → Request a Certificate)
   - Скачайте `.cer`, дважды кликните для импорта в Keychain

4. **Provisioning Profile**:
   - Profiles → **+** → **App Store** (или Ad Hoc для тестовых устройств)
   - App ID: `com.riotwwks.riogram`
   - Certificate: ваш Apple Distribution
   - Скачайте `.mobileprovision`

### 2. Экспорт .p12 для CI

На Mac, где сертификат в Keychain:

1. Keychain Access → **My Certificates** → `Apple Distribution: …`
2. Правый клик → **Export** → формат **Personal Information Exchange (.p12)**
3. Задайте пароль экспорта — он станет `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`

### 3. Локальная подпись

**Вариант A — через Xcode (проще для первого раза):**

```bash
./scripts/build-tdlib-ios.sh
open ios/Runner.xcworkspace   # или Runner.xcodeproj
```

В Xcode: Runner → Signing & Capabilities → Team → Automatic или Manual с вашим profile.

```bash
flutter build ipa --release
```

**Вариант B — через переменные окружения (как в CI):**

```bash
export IOS_DISTRIBUTION_CERTIFICATE_BASE64="$(base64 -i distribution.p12)"
export IOS_DISTRIBUTION_CERTIFICATE_PASSWORD='пароль_p12'
export IOS_PROVISIONING_PROFILE_BASE64="$(base64 -i RioGram.mobileprovision)"
export IOS_DEVELOPMENT_TEAM='XXXXXXXXXX'   # Team ID из developer.apple.com
export KEYCHAIN_PASSWORD='временный_пароль_keychain'
export IOS_EXPORT_METHOD=app-store         # или ad-hoc

./scripts/setup-ios-signing.sh
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

Результат: `build/ios/ipa/*.ipa`

### 4. Методы экспорта (IOS_EXPORT_METHOD)

| Значение | Назначение |
|----------|------------|
| `app-store` | Загрузка в App Store Connect / TestFlight (по умолчанию) |
| `ad-hoc` | Установка на зарегистрированные устройства (до 100) |
| `development` | Разработка на своих устройствах |
| `enterprise` | Корпоративное распространение (отдельная программа) |

Для GitHub Releases обычно нужен `app-store` (пользователи ставят через TestFlight/App Store) или `ad-hoc` (внутреннее тестирование).

### 5. Загрузка в App Store Connect

```bash
# Через Xcode Organizer или:
xcrun altool --upload-app -f build/ios/ipa/*.ipa \
  -u your@apple.id -p @keychain:AC_PASSWORD
```

Или используйте **Transporter** (Mac App Store).

### 6. Secrets для CI

| Secret | Описание |
|--------|----------|
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | `.p12` в base64 |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | пароль экспорта p12 |
| `IOS_PROVISIONING_PROFILE_BASE64` | `.mobileprovision` в base64 |
| `IOS_DEVELOPMENT_TEAM` | Team ID (10 символов, Membership → Team ID) |
| `KEYCHAIN_PASSWORD` | произвольный пароль для временного keychain на раннере |

Опционально — **Repository variable** (не secret):

| Variable | Значение по умолчанию |
|----------|----------------------|
| `IOS_EXPORT_METHOD` | `app-store` |

Без этих secrets job `build-ios` собирает unsigned `Runner.app` в zip (как раньше).

---

## GitHub Actions

Workflow: `.github/workflows/release.yml`

```
build-android:
  setup-android-signing.sh  →  flutter build apk/appbundle

build-ios:
  setup-ios-signing.sh      →  flutter build ipa (или --no-codesign)
```

Артефакты релиза:

| Файл | Подпись |
|------|---------|
| `RioGram-X.Y.Z-android-arm64.apk` | release, если заданы `ANDROID_*` |
| `RioGram-X.Y.Z-android.aab` | release, если заданы `ANDROID_*` |
| `RioGram-X.Y.Z-ios.ipa` | подписанный, если заданы `IOS_*` |
| `RioGram-X.Y.Z-ios-unsigned.zip` | fallback без iOS secrets |

Полный список secrets: [SECRETS.md](SECRETS.md).

### Рекомендуемый порядок настройки

1. Создайте keystore / Apple-сертификаты локально и проверьте сборку.
2. Добавьте secrets в GitHub.
3. Запустите **Actions → Release → Run workflow** (без публикации релиза) и проверьте артефакты.
4. Опубликуйте GitHub Release — артефакты прикрепятся автоматически.

---

## Безопасность

1. **Никогда** не коммитьте keystore, `.p12`, пароли, `key.properties`.
2. Храните резервные копии ключей в зашифрованном хранилище (не только в GitHub Secrets).
3. GitHub Secrets нельзя прочитать после сохранения — только перезаписать. Держите копию паролей отдельно.
4. Ограничьте доступ к Settings → Secrets (роли Admin/Maintainer).
5. Для production можно создать **Environment** `production` с required reviewers:  
   Settings → Environments → protection rules.
6. Secrets из fork PR **не передаются** в workflow — это защита от утечек.
7. Не выводите base64 secrets в лог (`echo $ANDROID_KEYSTORE_BASE64` — GitHub замаскирует, но не рискуйте).

---

## Устранение неполадок

### Android

| Ошибка | Решение |
|--------|---------|
| `Keystore was tampered with, or password was incorrect` | Проверьте `storePassword` / `keyPassword` |
| `Failed to read key … alias` | `keyAlias` должен совпадать с `-alias` при создании |
| Play Console: «подписан debug-ключом» | Добавьте `ANDROID_*` secrets или локальный `key.properties` |
| `storeFile` not found | Путь относительно `android/app/` или абсолютный |

### iOS

| Ошибка | Решение |
|--------|---------|
| `No signing certificate "iOS Distribution" found` | Импортируйте `.p12`, проверьте keychain в CI |
| `Provisioning profile doesn't match` | Profile должен быть для `com.riotwwks.riogram` |
| `Team ID mismatch` | `IOS_DEVELOPMENT_TEAM` = Team ID из Apple Developer |
| Сертификат истёк | Перевыпустите Distribution cert и profile, обновите secrets |
| `flutter build ipa` без ExportOptions | Запустите `setup-ios-signing.sh` или укажите `--export-options-plist` |

### CI

| Симптом | Решение |
|---------|---------|
| Android всё ещё debug-signed | Проверьте имя secret `ANDROID_KEYSTORE_BASE64` (точное совпадение) |
| iOS unsigned zip вместо ipa | Не задан `IOS_DISTRIBUTION_CERTIFICATE_BASE64` |
| base64 decode error | Кодируйте без переносов: `base64 -w0` (Linux) |

---

## Связанные документы

- [BUILD.md](BUILD.md) — сборка на всех платформах
- [SECRETS.md](SECRETS.md) — полный список GitHub Secrets
- [INSTALL.md](INSTALL.md) — установка для пользователей
- [Flutter: Android signing](https://docs.flutter.dev/deployment/android#signing-the-app)
- [Flutter: iOS deployment](https://docs.flutter.dev/deployment/ios)
