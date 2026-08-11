# Секреты и переменные окружения

Файл `.env` **не хранится в репозитории**. Для CI и релизных сборок используются **GitHub Actions Secrets**.

## Как это работает

1. Вы добавляете секреты в настройках репозитория на GitHub.
2. Workflow передаёт их как переменные окружения в `scripts/generate-env.sh`.
3. Скрипт создаёт `.env` на раннере перед `flutter build`.
4. `.env` попадает в asset-бандл приложения (см. `pubspec.yaml`).

Секреты **не попадают в git** и **маскируются в логах** Actions (GitHub заменяет значения на `***`).

## Кто видит секреты

| Роль | Доступ |
|------|--------|
| **Владелец / Admin** | Может создавать, обновлять и удалять secrets. **Нельзя прочитать** сохранённое значение — только перезаписать. |
| **Maintainer** | Обычно может управлять secrets (зависит от настроек организации). |
| **Write / Read collaborators** | **Не видят** значения secrets. |
| **Внешние пользователи / форки** | Secrets **не передаются** в workflow из fork PR. |

> Для максимальной изоляции релизов можно создать **Environment** `production` с обязательным approval и отдельными secrets:  
> Settings → Environments → New environment.

## Настройка в GitHub

1. Откройте репозиторий → **Settings** → **Secrets and variables** → **Actions**
2. Нажмите **New repository secret**
3. Добавьте секреты (имена должны совпадать **точно**):

| Secret | Обязателен | Описание |
|--------|------------|----------|
| `TELEGRAM_API_ID` | Да (release) | Числовой `api_id` с [my.telegram.org/apps](https://my.telegram.org/apps) |
| `TELEGRAM_API_HASH` | Да (release) | `api_hash` |
| `PROXY_PHANTOM_HOST` | Нет | Хост PhantomProxy |
| `PROXY_PHANTOM_PORT` | Нет | Порт (по умолчанию 443) |
| `PROXY_PHANTOM_SECRET` | Нет | Секрет MTProto |
| `PROXY_STEALTH_HOST` | Нет | Хост StealthGate Front |
| `PROXY_STEALTH_PORT` | Нет | Порт (по умолчанию 443) |
| `PROXY_STEALTH_SECRET` | Нет | Секрет StealthGate |

### Подпись мобильных сборок (Release)

Подробная инструкция: **[SIGNING.md](SIGNING.md)**

| Secret | Обязателен | Описание |
|--------|------------|----------|
| `ANDROID_KEYSTORE_BASE64` | Нет* | Release keystore (`.jks`) в base64 |
| `ANDROID_KEYSTORE_PASSWORD` | Нет* | Пароль хранилища |
| `ANDROID_KEY_PASSWORD` | Нет | Пароль ключа (если отличается от store) |
| `ANDROID_KEY_ALIAS` | Нет* | Alias ключа (например `riogram`) |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Нет* | Apple Distribution `.p12` в base64 |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | Нет* | Пароль экспорта p12 |
| `IOS_PROVISIONING_PROFILE_BASE64` | Нет* | Provisioning profile в base64 |
| `IOS_DEVELOPMENT_TEAM` | Нет* | Apple Team ID (10 символов) |
| `KEYCHAIN_PASSWORD` | Нет* | Пароль временного keychain в CI |

\* Без Android secrets APK/AAB подписываются **debug-ключом**. Без iOS secrets собирается **unsigned** zip. Для публикации в магазинах secrets обязательны.

Опциональная **variable** (не secret): `IOS_EXPORT_METHOD` = `app-store` | `ad-hoc` | `development` | `enterprise`.

### CI vs Release

| Workflow | Нужны secrets? |
|----------|----------------|
| **CI** (`ci.yml`) | Нет — `flutter analyze` и тесты работают с пустым `.env` |
| **Release** (`release.yml`) | **Да** — `TELEGRAM_API_ID` и `TELEGRAM_API_HASH` обязательны |

Без Telegram credentials релизная сборка завершится с ошибкой на шаге `Create .env from secrets`.

## Локальная разработка

```bash
cp .env.example .env
# Заполните значения вручную

# Или через переменные окружения:
export TELEGRAM_API_ID=12345678
export TELEGRAM_API_HASH=your_hash_here
./scripts/generate-env.sh
```

## Безопасность

- **Не коммитьте** `.env` — он в `.gitignore`.
- **Не печатайте** secrets в workflow (`echo $TELEGRAM_API_HASH` — GitHub замаскирует, но лучше не делать).
- **Не встраивайте** secrets в имена артефактов или release notes.
- Прокси-секреты тоже храните только в GitHub Secrets / локальном `.env`.

## Связанные файлы

- `scripts/generate-env.sh` — генерация `.env`
- `scripts/setup-android-signing.sh` — Android keystore в CI
- `scripts/setup-ios-signing.sh` — iOS codesign в CI
- `.github/workflows/release.yml` — использует secrets
- `.env.example` — шаблон для локальной разработки
- `docs/SIGNING.md` — подпись Android/iOS
