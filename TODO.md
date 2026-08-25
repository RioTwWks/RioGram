# TODO.md — Детальный список задач для разработки MVP

## ❗ Условные обозначения
- `[ ]` — задача не начата
- `[~]` — задача в процессе
- `[x]` — задача выполнена
- `⏳` — ожидает завершения предыдущей задачи

**Последнее обновление:** §8 Web (PoC → E2E), актуализация `.cursor/` и docs.

---

## 0. Подготовка инфраструктуры и окружения

### 0.1. Получение API-ключей Telegram
- [x] Зарегистрировать приложение на [my.telegram.org](https://my.telegram.org/apps) → получить `api_id` и `api_hash`.
- [x] Сохранить ключи в защищённом месте (не коммитить в репозиторий).

### 0.2. Настройка VPS-серверов
- [x] Арендовать два VPS в РФ (например, у TimeWeb, Vscale или RU-VDS).
- [x] Арендовать (или использовать имеющийся) VPS в Европе (для backend StealthGate).
- [~] Установить базовое ПО: Docker, Git, curl, wget, build-essential.

### 0.3. Развертывание прокси-серверов
- [~] Собрать и запустить **PhantomProxy** на основном VPS в РФ.
- [~] Развернуть **StealthGate** в сплит-режиме (Front RU + Back EU).
- [~] Проверить связку через тестовое подключение.

### 0.4. Проверка прокси
- [~] Подключиться через официальный Telegram Desktop — убедиться, что работает.
- [x] Зафиксировать IP-адреса и порты для использования в `.env`.

### 0.5. Установка инструментов разработки
- [x] Установить Flutter SDK (≥3.22) с поддержкой всех платформ.
- [x] Добавить CMake-скрипт сборки TDLib (`scripts/build-tdlib.sh`).
- [ ] Настроить эмуляторы/симуляторы для мобильных платформ.

---

## 1. Базовое Flutter-приложение с TDLib

### 1.1. Создание проекта
- [x] `flutter create --org com.riotwwks riogram`
- [x] Настроить структуру папок: `lib/core`, `lib/screens`, `lib/widgets`, `lib/models`.

### 1.2. Добавление зависимостей
- [x] `provider`, `shared_preferences`, `path_provider`, `ffi`, `flutter_dotenv`
- [x] Выполнить `flutter pub get`.

### 1.3. Интеграция TDLib
- [x] Класс `TdlibClient`: `init()`, `send()`, поток `updates`, `waitFor()`
- [x] FFI-обёртка `tdlib_bindings.dart`

### 1.4. Реализация авторизации
- [x] Экран ввода номера телефона
- [x] `setAuthenticationPhoneNumber` / `checkAuthenticationCode`
- [x] Обработка 2FA (`checkAuthenticationPassword`)
- [ ] Сохранять состояние авторизации после перезапуска (`getAuthorizationState`)

### 1.5. Базовый UI: список чатов
- [x] Подписка на `updateNewChat` / `getChats`
- [x] Отображение списка чатов
- [x] Реализовать навигацию при клике на чат (экран переписки)

---

## 2. Модификация TDLib для обхода DPI

### 2.1. Изучение исходного кода TDLib
- [x] Клонировать TDLib в `td/`
- [x] Найти ключевые файлы: `TlsInit.cpp`, `TcpTransport.cpp`

### 2.2. Реализация рандомизации ClientHello
- [x] 4 профиля: Chrome, Firefox, Yandex, Safari
- [x] Случайный выбор при каждом подключении

### 2.3. Фрагментация пакетов
- [x] ClientHello → 2–3 TCP-фрагмента (`dpi_bypass/DpiBypass.cpp`)

### 2.4. Динамическое изменение размеров записей (DRS)
- [x] `pick_random_record_size()` в `TcpTransport.cpp`

### 2.5. Подмена TLS-стека (fingerprint)
- [x] Разные профили браузеров с уникальными cipher suites / extensions
- [ ] Полевое тестирование на сетях провайдеров

### 2.6. Сборка модифицированного TDLib
- [x] Скрипт `scripts/build-tdlib.sh` (Linux)
- [x] Скрипты для Windows, macOS, Android, iOS (`scripts/build-tdlib-*.sh`)
- [x] `scripts/copy-tdlib.sh` — интеграция libtdjson в Flutter-проект

### 2.7. Тестирование обхода DPI
- [ ] Запустить клиент через PhantomProxy и StealthGate
- [ ] Протестировать на сетях разных провайдеров
- [ ] Логировать успешность подключения и время отклика

---

## 3. Прокси и автоматическое переключение

### 3.1. Интеграция прокси в TDLib
- [x] `addProxy` с типом `proxyTypeMtproto`
- [x] PhantomProxy (основной) и StealthGate (резервный) из `.env`

### 3.2. Проверка доступности прокси
- [x] `pingProxy` с таймаутом 5 секунд
- [x] Периодическая проверка каждые 30 секунд

### 3.3. Логика автоматического переключения
- [x] Переключение при недоступности активного прокси
- [x] Fallback: сообщение «Все прокси недоступны»
- [x] Переключение без перезапуска приложения
- [x] Реакция на `connectionStateWaitingForNetwork`

### 3.4. UI для управления прокси
- [x] Экран настроек: текущий прокси, список, тест, ручное включение
- [x] Переключатель автоматического failover (SharedPreferences)

### 3.5. Индикация статуса прокси
- [x] Индикатор на экране чатов (зелёный / жёлтый / красный / серый)

---

## 4. UI и кастомизация (полировка интерфейса)

> Базовый MVP-интерфейс. Целевой вид «как классический Telegram» — §9; расширенная кастомизация сверх него — §7.3.

### 4.1. Система тем
- [x] Светлая и тёмная тема с выбором акцентного цвета
- [x] Сохранение в `SharedPreferences`

### 4.2. Основные экраны
- [x] Экран чатов — адаптивный master-detail (≥720px)
- [x] Экран переписки
- [x] Экран настроек (прокси + тема + выход)

### 4.3. Функции чата
- [x] Отправка текстовых сообщений
- [x] Отображение фото (локальный файл после downloadFile)
- [x] Отправка файлов (file_picker)
- [x] Воспроизведение видео inline

### 4.4. Уведомления
- [x] `flutter_local_notifications` для входящих сообщений

### 4.5. Дополнительные улучшения UX
- [x] Статус «печатает…»
- [x] Голосовые сообщения
- [x] Кэширование медиа

---

## 5. Сборка и тестирование на всех платформах

### 5.1. Сборка десктопных версий
- [x] Скрипты и документация: [docs/BUILD.md](docs/BUILD.md)
- [x] CI: полная сборка Linux (`flutter-linux` job)
- [x] Release workflow: Linux, Windows, macOS

### 5.2. Сборка мобильных версий
- [x] Release workflow: Android APK/AAB, iOS IPA (signed / unsigned fallback)
- [x] Скрипты `build-tdlib-android.sh`, `build-tdlib-ios.sh`
- [x] Подпись Android/iOS: `setup-*-signing.sh`, `docs/SIGNING.md`, Gradle + ExportOptions

### 5.3. Интеграционные тесты
- [x] Тесты `ProxyPreferences`, `ProxyEntry`, `chat_models`, `theme`
- [ ] Тесты авторизации и failover с mock TDLib

### 5.4. Полевое тестирование
- [ ] Бета-тестеры, сбор логов

### 5.5. Подготовка к релизу
- [x] CI/CD — GitHub Actions
- [x] Release workflow — все платформы
- [x] Инструкции: [docs/INSTALL.md](docs/INSTALL.md), [docs/BUILD.md](docs/BUILD.md)
- [x] `android/key.properties.example` для release-подписи
- [x] Подпись Android (release keystore) и iOS (codesign / IPA) — см. docs/SIGNING.md
- [ ] Иконки приложения

---

## 6. Паритет с официальным клиентом Telegram (функционал)

**Цель:** довести RioGram до уровня, когда пользователь может **полноценно заменить** официальный клиент Telegram — те же сценарии, те же действия, тот же результат. Речь только о **поведении и возможностях**, не о внешнем виде (дизайн — §9).

**Уже закрыто MVP (§1–§5):** авторизация по номеру, список чатов, текст/фото/файлы, уведомления, прокси, базовые темы.

**Не входит в §6:**
- уникальные фишки RioGram (Ghost Mode, анти-отзыв, Local Premium) — §7;
- визуальный стиль «как Telegram до Liquid Glass» — §9;
- браузерная версия — §8.

**Как читать чеклист:** каждый подпункт — конкретная возможность официального клиента. `[x]` ставить только когда функция работает end-to-end на целевых платформах.

---

### 6.1. Авторизация, сессии и аккаунты

#### Базовая авторизация (частично в MVP)
- [x] Вход по номеру телефона + SMS-код
- [x] Облачный пароль (2FA)
- [x] Сохранение сессии после перезапуска (`authorizationStateReady` без повторного входа) — TDLib SQLite + `AuthManager`
- [x] QR-вход (`requestQrCodeAuthentication`, `authorizationStateWaitOtherDeviceConfirmation`)
- [x] Регистрация нового аккаунта (`registerUser`) — имя, фамилия, terms of service
- [x] Смена номера (`sendPhoneNumberCode` + `phoneNumberCodeTypeChange`, `checkPhoneNumberCode`)
- [x] Подтверждение email при входе (`setAuthenticationEmailAddress`, `checkAuthenticationEmailCode`)

#### Множественные аккаунты
- [x] Модель `AccountSession`: отдельные `database_directory` / `files_directory` на аккаунт
- [x] Добавление второго и последующих аккаунтов без выхода из первого
- [x] Переключение аккаунта без смешивания чатов и уведомлений
- [x] `logOut` / удаление аккаунта с устройства
- [x] Общие или per-account настройки прокси (`.env` общий; SOCKS5/HTTP per-account — политика в настройках)

#### Безопасность сессии
- [x] Активные сессии: `getActiveSessions`, завершение (`terminateSession` / `terminateAllOtherSessions`)
- [x] Passcode / биометрия на уровне приложения (локальная блокировка UI)
- [x] Автоблокировка по таймауту неактивности

---

### 6.2. Список чатов и организация

#### Отображение и сортировка
- [x] Основной список (`getChats`, `chatListMain`)
- [x] Закреплённые чаты (`updateChatPosition`, `pinChat` / `unpinChat`)
- [x] Архив (`chatListArchive`, свайп «В архив» / «Из архива»)
- [x] Папки чатов (`chatListFolder`, `updateChatFolders`, переключение вкладок)
- [x] Счётчик непрочитанных, mute (`notificationSettings`), иконка mute в списке
- [x] Черновик сообщения в preview (`draftMessage`)
- [x] Иконки типа чата: личный, группа, канал, бот, секретный

#### Действия со списком
- [x] Поиск по чатам (`searchChats`, `searchMessages` глобально)
- [x] Удаление / очистка истории (`deleteChatHistory`, `leaveChat`)
- [x] Отметить как прочитанное (`toggleChatIsMarkedAsUnread`)
- [x] «Избранное» / Saved Messages (`chatTypeSecret` / специальный чат «Избранное»)

#### Десктопная навигация
- [x] Master-detail ≥720px (базово)
- [x] Трёхколоночный layout как Telegram Desktop: папки | чаты | переписка
- [x] Горячие клавиши: поиск, новый чат, навигация по чатам

---

### 6.3. Сообщения и переписка

#### Отправка и форматирование
- [x] Текстовые сообщения
- [x] Форматирование: жирный, курсив, код, ссылка (`textEntity*`, `inputMessageText.entities`)
- [x] Ответ (reply): `inputMessageReplyToMessage`, отображение цитаты
- [x] Пересылка: `forwardMessages`, выбор нескольких, «переслать без автора»
- [x] Упоминания `@username` и `#hashtag` (парсинг и подсветка entities)
- [x] Отложенная отправка (`messageSchedulingState`, `editMessageSchedulingState`)
- [x] «Печатает…» / запись голосового / выбор стикера (`sendChatAction`) — typing есть в MVP

#### Редактирование и удаление
- [x] `editMessageText` / `editMessageCaption` (проверка `can_be_edited`, окно 48 ч)
- [x] `deleteMessages` с `revoke: true` (для всех) и `revoke: false` (только у себя)
- [x] Пакетный выбор сообщений (long-press → режим выделения)
- [x] Обработка `updateMessageEdited`, `updateDeleteMessages`, `updateMessageContent`
- [x] Метки «изменено» / «удалено» в модели `ChatMessage`

#### Статусы доставки
- [x] Галочки отправлено / доставлено / прочитано (`messageSendingState`, `updateMessageSendSucceeded`)
- [x] Счётчик просмотров в каналах (`messageInteractionInfo`)

#### Реакции и опросы
- [x] Просмотр и добавление реакций (`addMessageReaction`, `removeMessageReaction`)
- [x] Опросы: создание (`sendPoll`), голосование (`setPollAnswer`), викторины
- [x] Кнопки под сообщениями (`replyMarkup`, inline keyboard)

---

### 6.4. Медиа и вложения

#### Фото и видео
- [x] Отправка и просмотр фото
- [x] Inline-воспроизведение видео (§4.3)
- [x] Альбомы / группы медиа (`groupedId`, `messages` с общим альбомом)
- [x] Сжатие vs «как файл» при отправке фото/видео
- [x] Видеосообщения («кружочки»): `inputMessageVideoNote`, `messageVideoNote`
- [x] Просмотрщик медиа на весь экран: зум, свайп между фото, сохранить

#### Аудио и файлы
- [x] Отправка документов (`file_picker`)
- [x] Голосовые сообщения: запись, `inputMessageVoice`, воспроизведение с waveform
- [x] Аудиофайлы / музыка: `messageAudio`, встроенный плеер, метаданные (исполнитель, обложка)
- [x] Прогресс загрузки/скачивания (`updateFile`, `uploadFile`, `cancelUploadFile`)

#### Кэш и автозагрузка
- [x] Кэширование медиа на диск (§4.3)
- [x] Настройки автозагрузки по типу сети (`autoDownloadSettings` — Wi‑Fi / mobile / roaming)
- [x] Очистка кэша (`optimizeStorage`, выборочное удаление)

#### Стикеры и GIF
- [x] Отправка стикеров (`inputMessageSticker`, `messageSticker`)
- [x] Панель стикеров: наборы, избранное, недавние (`getInstalledStickerSets`, `searchStickers`)
- [x] GIF: `searchAnimatedEmojis` / `searchGifs`, `inputMessageAnimation`
- [x] Стикерпаки: установка по ссылке, просмотр набора

---

### 6.5. Группы, каналы и форумы

#### Типы и создание
- [x] Парсинг `chatType`: private, basic group, supergroup, channel
- [x] `createNewSupergroupChat` — группа и канал (`is_channel`)
- [x] `createNewBasicGroupChat`, `upgradeBasicGroupChatToSupergroupChat`
- [x] Вступление: `joinChat`, `joinChatByInviteLink`, `searchPublicChat`

#### Управление
- [x] Экран информации о чате: описание, ссылка-приглашение, участники
- [x] Админ-права: `setChatMemberTag`, `setChatPermissions`, бан/разбан
- [x] Закрепление сообщений (`pinChatMessage`, `unpinChatMessage`)
- [x] Медленный режим, антиспам, одобрение новых участников (read-only настройки для админов)

#### Каналы и комментарии
- [x] Read-only режим для подписчиков канала
- [x] Подписка / отписка (`joinChat` / `leaveChat`)
- [x] Комментарии к постам (связанная группа-обсуждение)

#### Форумы (topics)
- [x] `forumTopic`, список тем, создание темы
- [x] Отправка в конкретную тему (`messageThreadId`)
- [x] General topic vs именованные топики

#### Групповая переписка
- [x] Имя отправителя у входящих (`messageSenderUser`, `messageSenderChat`)
- [x] Упоминание `@all` / `@admins` (где разрешено)
- [x] Служебные сообщения: «X вступил в группу» (`messageChatAddMembers` и др.)

---

### 6.6. Звонки и геолокация

#### Голосовые и видеозвонки (VoIP)
- [x] `createCall` / `acceptCall` / `discardCall` — аудио 1:1
- [x] Видеозвонки: `createCall(is_video)`, превью камеры, локальный toggle видео
- [x] Групповые звонки / конференции (`createGroupCall`, `joinGroupCall`) — низкий приоритет
- [x] WebRTC-интеграция, CallKit (iOS), foreground service (Android)
- [x] Выбор устройств ввода/вывода на десктопе
- [x] История звонков (`messageCall`)

#### Геолокация
- [x] Отправка точки на карте (`inputMessageLocation`)
- [x] Live Location: трансляция, `editMessageLiveLocation`, остановка
- [x] Venues / места (`inputMessageVenue`)
- [x] Открытие координат во внешней карте

---

### 6.7. Контакты и профили

#### Контакты
- [x] Список контактов (`getContacts`, `searchContacts`)
- [x] Импорт из адресной книги (`importContacts`, `flutter_contacts`)
- [x] Добавление / удаление контакта (`addContact`, `removeContacts`)
- [ ] «Люди рядом» (`searchNearbyUsers`) — N/A, API отсутствует в td_api.tl

#### Профиль пользователя
- [x] Свой профиль: имя, bio, username, аватар (`setProfilePhoto`, `setBio`, `setName`, `setUsername`)
- [x] Просмотр чужого профиля: `getUserFullInfo`, общие чаты
- [x] Блокировка (`blockMessageSenderFromReplies`, `setMessageSenderBlockList`)
- [x] Статусы онлайн / «был(а) недавно» (`userStatusOnline`, `userStatusOffline`)

---

### 6.8. Поиск и обнаружение

- [x] Глобальный поиск сообщений (`searchMessages`, фильтры: медиа, ссылки, файлы)
- [x] Поиск по чату (`searchChatMessages`)
- [x] Поиск публичных каналов и ботов (`searchPublicChats`)
- [x] Поиск по username (`searchUserByPhoneNumber`, `searchUserByToken`, `searchPublicChat`)
- [x] Inline-результаты с прокруткой и переходом к сообщению в контексте

---

### 6.9. Настройки, уведомления и приватность

#### Уведомления
- [x] Локальные push при входящем сообщении (базово)
- [x] Настройки на чат: mute, звук, preview (`setChatNotificationSettings`)
- [x] Глобальные настройки уведомлений (`getScopeNotificationSettings` / `setScopeNotificationSettings`)
- [x] Счётчик непрочитанных на иконке приложения (badge)

#### Приватность
- [x] Кто видит номер, фото, статус онлайн, «был(а)» (`userPrivacySetting*`)
- [x] Кто может писать / звонить / добавлять в группы
- [x] Двухэтапная аутентификация, облачный пароль в настройках
- [x] Автоудаление сообщений (`setChatMessageAutoDeleteTime`)

#### Данные и хранилище
- [x] Использование памяти: разбивка по типам, очистка
- [ ] Экспорт чата — N/A, `exportChat` отсутствует в TDLib API
- [x] Язык интерфейса (`setOption` / локализация приложения)

#### Прокси (уже в MVP, §3)
- [x] MTProto-прокси, failover, ручное управление
- [x] SOCKS5 / HTTP-прокси (`proxyTypeSocks5`, `proxyTypeHttp`) — как в официальном клиенте
- [x] Список прокси из `.env` + пользовательские

---

### 6.10. Боты, inline и Mini Apps

- [x] Распознавание ботов (`userTypeBot`), отдельный UI где нужно
- [x] Inline-кнопки и клавиатуры (`replyMarkupInlineKeyboard`, callback `getCallbackQueryAnswer`)
- [x] Inline-режим (`inlineQuery`) — поиск через бота в любом чате
- [x] Telegram Mini Apps / Web Apps (`openWebApp`, `answerWebAppQuery`)
- [x] Команды бота (`/start`, меню команд `botCommands`)

---

### 6.11. Секретные чаты

- [x] Включить `use_secret_chats` в `setTdlibParameters`
- [x] Создание секретного чата (`createNewSecretChat`)
- [x] E2E-шифрование: обмен ключами, индикатор «секретный чат»
- [x] Таймер самоуничтожения (`setChatMessageAutoDeleteTime` / `messageSelfDestructTypeTimer`)
- [x] Скриншот-уведомления (`messageScreenshotTaken`)

---

### 6.12. Stories (истории)

- [x] Лента историй контактов (`loadActiveStories`, `getChatActiveStories`, `updateChatActiveStories`)
- [x] Просмотр истории (`openStory`, `closeStory`, `getStory`)
- [x] Публикация фото/видео-истории (`postStory`, `canPostStory`) — если аккаунт поддерживает
- [x] Реакции и ответы на истории (`setStoryReaction`, `sendMessage` + `inputMessageReplyToStory`)

---

### 6.13. Фазы внедрения (приоритет)

| Фаза | Блоки §6 | Результат для пользователя |
|------|----------|----------------------------|
| **A** | 6.3 (edit/delete/reply), 6.4 (voice, video inline, cache) | Комфортная ежедневная переписка |
| **B** | 6.5 (группы, каналы), 6.7 (контакты) | Работа в сообществах |
| **C** | 6.6 (VoIP, гео), 6.1 (мультиаккаунт, сессии) | Звонки и несколько номеров |
| **D** | 6.8, 6.9, 6.4 (стикеры/GIF) | Полнота «как Telegram» |
| **E** | 6.10, 6.11, 6.12 | Боты, секретные чаты, stories |

**Критерий полного §6:** пользователь неделю пользуется RioGram как основным клиентом и не вынужден открывать официальный Telegram для рутинных задач.

**Визуальная часть** каждого экрана из §6 оформляется по §9.

---

## 7. Дорожная карта развития (после MVP)

MVP — прочный фундамент. Ниже — направления, как превратить RioGram в по-настоящему уникальный продукт.  
**Приоритет (совет):** начать с **«Призрачного режима»** и **«Анти-отзыва»**, затем встроенный переводчик и углублённая кастомизация UI.

### 7.1. Продвинутые техники обхода блокировок (стелс)

- [x] Маскировка под легитимные российские сервисы (Yandex, VK, Gosuslugi) вместо только случайного выбора браузерного профиля — см. [docs/STEALTH.md](docs/STEALTH.md)
- [x] Probe Resistance — корректная реакция прокси на «проверочные» запросы DPI без раскрытия природы сервиса (документация + рекомендации для PhantomProxy/StealthGate/telemt)
- [x] Исследовать интеграцию с [telemt](https://github.com/telemt) / teleproxy как бэкенд с улучшенным Fake-TLS — см. [docs/STEALTH.md](docs/STEALTH.md) §4
- [x] Автосмена TLS-отпечатка (Chrome / Firefox / Yandex / VK / Gosuslugi) по таймеру или при проблемах с соединением — `kDpiBypassAutoRotateProfiles` в `DpiBypass.h`

### 7.2. Расширение пользовательских функций

#### Призрачный режим (Ghost Mode)
- [x] Скрытие статуса «онлайн»
- [x] Скрытие статуса «печатает…»
- [x] Скрытие подтверждений о прочтении (галочки)
- [x] Просмотр «исчезающих» медиа без уведомления отправителя

#### Анти-отзыв и медиа
- [x] Анти-отзыв (Anti-Recall): видеть удалённые и отредактированные сообщения
- [x] Встроенный видеоплеер с изменением скорости воспроизведения
- [x] Предпросмотр фото/видео при наведении (как на macOS)
- [x] Встроенный переводчик сообщений в чате

> Базовый функционал (звонки, мультиаккаунт, группы) — §6. Визуальный стиль — §9.

### 7.3. Глубокая кастомизация интерфейса (сверх §9)

Расширения **поверх** классического вида Telegram из §9 — не путать с паритетом дизайна.

- [x] Расширенные темы: произвольный акцентный цвет, шрифты (например Google Sans), скругления углов
- [x] Скрытие элементов UI (кнопка mute, панель навигации, иконки)
- [x] Настраиваемые жесты (свайпы по чатам и сообщениям)

### 7.4. Безопасность и приватность

- [x] Local Premium: локальная разблокировка отдельных «премиум»-возможностей (например лимиты загрузки)
- [x] Блокировка рекламы в каналах и ботах
- [x] Отключение телеметрии Telegram (или только с явного согласия пользователя)

### 7.5. Интеграции и фишки

- [x] Поддержка Telegram Mini Apps — bridge `Telegram.WebApp`, Main/Back button, `sendWebAppData`, custom requests
- [x] Поддержка LaTeX в сообщениях (рендер формул) — `$...$`, `$$...$$`, `\(...\)`, `\[...\]`
- [x] Интеграции с внешними сервисами (автопостинг в личный канал / бот)

### 7.6. Долгосрочные идеи

- [x] Экосистема плагинов (API для community-расширений) — `RioGramPlugin`, `PluginManager`, встроенные плагины, `docs/PLUGINS.md`
- [x] Исследование децентрализованной модели поверх протокола Telegram — `docs/DECENTRALIZATION.md`, in-app дорожная карта

### 7.7. Синхронизация с upstream TDLib

Нужно следить за обновлениями [оригинального TDLib](https://github.com/tdlib/td) и переносить патчи `DPI_BYPASS` на новые версии.

- [x] Настроить уведомления о новых релизах upstream TDLib (GitHub Releases / watch repo) — scheduled workflow + Issue
- [x] Добавить CI job или scheduled workflow: проверка нового тега `tdlib/td` → issue или Telegram-бот / email — [`.github/workflows/tdlib-upstream-sync.yml`](.github/workflows/tdlib-upstream-sync.yml)
- [x] Документировать процесс merge upstream → `td/` (чеклист: `TDLIB_PATCHES.md`, конфликты, регрессия DPI) — [docs/TDLIB_UPSTREAM_SYNC.md](docs/TDLIB_UPSTREAM_SYNC.md)
- [x] Зафиксировать в репозитории текущую базовую версию upstream TDLib (commit / tag) — [`td/upstream-base.json`](td/upstream-base.json)

Варианты нотификации:
- GitHub Action `schedule` + `gh api repos/tdlib/td/releases/latest`
- Dependabot-style custom workflow → создание Issue «Доступен TDLib vX.Y.Z»
- Подписка на RSS/Atom релизов GitHub + внешний сервис (IFTTT, n8n)

---

## 8. Web-платформа RioGram (браузерный клиент с обходом блокировок)

Цель: дать пользователям доступ к RioGram через браузер **без VPN и прокси на устройстве**.  
Главный вызов — не сборка Flutter Web, а **транспорт и инфраструктура**: в браузере нельзя применить Fake TLS / фрагментацию MTProto, поэтому трафик заворачивается в **WebSocket (WSS)** и проксируется через схему **RU Frontend → EU Backend**.

```
Пользователь (РФ) → RU VPS (Nginx + SSL) → SSH-туннель → EU-сервер (RioGram Web + WSS-прокси) → Telegram
```

**Важно:** размещать веб-версию напрямую на EU-сервере нельзя — высокий риск блокировки IP Роскомнадзором. EU-сервер остаётся скрытым за российским VPS-посредником.

### 8.1. Исследование и проверка концепции (PoC)

- [x] Собрать текущий Flutter-проект для Web: `flutter build web --release` — `./scripts/build-web.sh` (tdweb + `lib/main.dart`); UI PoC: `./scripts/build-web-poc.sh`
- [x] Задеплоить статику на тестовый хостинг, убедиться что UI работает без подключения к Telegram — `build/web/` + `python3 -m http.server`
- [x] Зафиксировать несовместимости Web-платформы (FFI/TDLib, `dart:ffi`, нативные плагины) — см. [docs/WEB_POC.md](docs/WEB_POC.md)
- [x] Изучить готовые решения:
  - [x] [tg-ws-proxy](https://github.com/Flowseal/tg-ws-proxy) — локальный SOCKS5→WSS, не server-side для Web
  - [x] [tg-proxy](https://github.com/AlexMelanFromRingo/tg-proxy) — Rust SOCKS5→WSS, референс алгоритма bridge
  - [x] [telegram-tt](https://github.com/Ajaxy/telegram-tt) — GramJS + browser WSS; форки с Proxy Hook + TG-WS-API
  - [x] [tdlib-obf](https://github.com/telemt/tdlib-obf) — stealth для native MTProto proxy, не для браузера
- [x] Выбрать стратегию транспорта: **Вариант А** (WSS reverse proxy RU→EU→Telegram + tdweb/GramJS в клиенте) — см. [docs/WEB_POC.md](docs/WEB_POC.md)

### 8.2. WebSocket-транспорт для TDLib

В браузере сетевой стек контролируется самим браузером — MTProto нужно туннелировать через **WSS (порт 443)**, чтобы для DPI это выглядело как обычный HTTPS к легитимному домену.

- [x] Спроектировать транспортный слой: TDLib ↔ WebSocket (WSS) вместо TCP/Fake TLS — см. [docs/WEB_TRANSPORT.md](docs/WEB_TRANSPORT.md)
- [x] Реализовать или интегрировать WSS-обёртку для исходящих/входящих пакетов TDLib — `web/js/wss_proxy_hook.js`
- [x] Адаптировать `TdlibClient` / FFI-слой для Web-платформы (отдельная реализация без нативного `libtdjson`) — `tdlib_client_web.dart` + conditional imports
- [x] Поддержать настройку адреса WSS-прокси в клиенте (например `wss://your-proxy-domain.ru/`) — `WebSocketProxyPreferences`, `WebProxyManager`
- [x] Добавить в UI настройки поле для WebSocket-прокси (аналог экрана прокси, но для Web) — `WebSocketProxySettings`
- [x] Обеспечить автоматическое переподключение при обрыве WSS-соединения — `WebProxyManager._scheduleReconnect()`
- [x] Собрать и подключить tdweb WASM (`td/example/web`) для полной авторизации в браузере — `./scripts/build-tdweb.sh`, `./scripts/copy-tdweb.sh`, `web/index.html`

### 8.3. Web-прокси (серверная часть)

- [x] Развернуть WSS-прокси на EU-сервере (принимает WebSocket от браузера, перенаправляет в Telegram) — `server/wss-proxy`, `bin/riogram-wss-proxy`
- [x] Вариант А: собственная реализация MTProto-прокси через WebSocket — **WSS reverse proxy** (совместим с TG-WS-API / §8.2 URL rewrite)
- [ ] Вариант Б: адаптировать StealthGate / PhantomProxy для приёма WSS-соединений — **не требуется** для Web (см. [WEB_POC.md](docs/WEB_POC.md))
- [ ] Вариант В: развернуть готовый `tg-ws-proxy` или аналог — **отклонено** (SOCKS5/desktop-only)
- [x] Настроить прокси на прослушивание только `127.0.0.1` (доступ только через SSH-туннель с RU VPS) — `WSS_PROXY_LISTEN=127.0.0.1:5001`
- [x] Протестировать прокси локально (`wscat`, curl) до подключения клиента — `./scripts/test-wss-proxy.sh`, `go test ./...`

### 8.4. Инфраструктура: RU Frontend + EU Backend

Схема защиты EU-сервера от блокировки РКН: российский VPS — публичная точка входа, EU-сервер — скрытый backend.

#### 8.4.1. Подготовка серверов

- [ ] Арендовать (или выделить) VPS в РФ для frontend — **ручной шаг ops**
- [x] Подготовить EU-сервер: приложение слушает `127.0.0.1` — `setup-web-infra-eu.sh`, порты 5001/8080, static `/opt/riogram/web`
- [x] Обновить системы на обоих серверах — `apt-get` в setup-скриптах

#### 8.4.2. SSH-туннель (EU → RU)

- [x] Reverse SSH-туннель EU→RU — `scripts/autossh-riogram-tunnel.sh`, `autossh-riogram-tunnel.service`
- [x] `autossh` на EU — устанавливается `setup-web-infra-eu.sh`
- [x] systemd `autossh-riogram-tunnel.service` — `deploy/systemd/`
- [x] Проверка туннеля с RU — `./scripts/verify-web-tunnel.sh`

#### 8.4.3. Nginx на RU VPS (reverse proxy + WSS)

- [x] Nginx + Certbot — `setup-web-infra-ru.sh`
- [x] Конфиг `riogram-ru.conf.template` — proxy_pass, Upgrade, timeouts
- [x] Активация sites-available — в setup-скрипте

#### 8.4.4. SSL и брандмауэр

- [x] Let's Encrypt инструкция — certbot в setup + `WEB_INFRA.md`
- [x] UFW RU (22, 80/443) — `deploy/ufw/riogram-ru.sh`
- [x] UFW EU (SSH only) — `deploy/ufw/riogram-eu.sh`
- [x] Ограничение EU SSH по IP RU — `EU_UFW_ALLOW_SSH_FROM` в web.env

### 8.5. Сборка и деплой Flutter Web

- [x] Добавить Web в `flutter build` pipeline (CI / release workflow) — job `flutter-web` в `.github/workflows/ci.yml`
- [x] Настроить `web/index.html` (base href, meta, service worker) — см. [docs/WEB.md](docs/WEB.md)
- [x] Собрать production-билд: `flutter build web --release` — `./scripts/build-web.sh`
- [x] Развернуть `build/web/` на EU-сервере — `./scripts/deploy-web-eu.sh` → `/opt/riogram/web`
- [ ] Проверить загрузку приложения по `https://your-domain.ru` из браузера в РФ — **ручной E2E (§8.6)**

### 8.6. Тестирование

- [x] UI: интерфейс загружается, навигация работает — Playwright `e2e/web/tests/smoke.spec.js`
- [ ] Авторизация: вход по номеру телефона через WSS-транспорт — **ручной чеклист** [WEB_E2E.md](docs/WEB_E2E.md)
- [x] WebSocket: соединение устанавливается — `e2e-wss-stability.sh`, Playwright hook test
- [x] Стабильность: WSS не обрывается через 60+ сек — `WSS_STABILITY_SECONDS=65 ./scripts/e2e-wss-stability.sh`
- [ ] Туннель: переподключение autossh после обрыва SSH — **ручной чеклист** [WEB_E2E.md](docs/WEB_E2E.md)
- [ ] Доступ из РФ без VPN/прокси на устройстве пользователя — **ручной чеклист** [WEB_E2E.md](docs/WEB_E2E.md)

### 8.7. Устранение неполадок (чеклист)

- [x] **502 Bad Gateway** — `./scripts/verify-web-tunnel.sh`, `docs/WEB_INFRA.md`
- [x] **WebSocket сразу закрывается** — nginx template + troubleshooting
- [x] **WebSocket падает через минуту** — `proxy_read_timeout 86400s`
- [x] **Туннель рвётся** — autossh systemd + `Restart=always`

### 8.8. Документация

- [x] Создать `docs/WEB.md`: архитектура, сборка, деплой, настройка прокси
- [x] Описать схему RU Frontend → EU Backend в `docs/PROXY.md` (раздел Web)
- [x] Добавить команды деплоя в `.cursor/commands/` — `web.md`, `deploy-web-app.md`, `deploy-web-infra.md`, `deploy-web-proxy.md`, `e2e-web.md`
- [x] Актуализировать `.cursor/context`, `.cursor/rules/`, `docs/CI.md`, `docs/QUICKSTART.md`

---

## 9. Дизайн в стиле классического Telegram (до Liquid Glass)

**Цель:** визуально RioGram должен ощущаться как **официальный Telegram до редизайна Liquid Glass** (iOS 26 / macOS Tahoe, ~2025) — плоский, читаемый, без frosted glass, без размытых «стеклянных» панелей.

**Референсы для сверки:**
- Telegram Desktop 4.x–5.x (трёхколоночный layout, нейтральные серые фоны)
- Telegram Android / iOS **до** обновления с полупрозрачными tab bar и blur-эффектами
- [Telegram UI Kit](https://www.figma.com/community/file/867601279089856700) (community) — ориентир по отступам и компонентам

**Не входит в §9:** уникальная кастомизация RioGram (произвольные шрифты, скрытие UI) — §7.3.  
**Связь с §6:** каждый новый экран из функционального чеклиста сначала получает «телеграмный» вид по §9, затем при необходимости кастомизируется.

**§9.11 — pixel parity:** базовые чеклисты §9.1–§9.9 отмечают «есть компонент», но не гарантируют совпадение отступов/размеров с Telegram Desktop / Android. Детальная полировка и side-by-side аудит — в **§9.11**; ложные `[x]` в §9.1–§9.9 сняты по результатам аудита.

---

### 9.1. Дизайн-система и токены

Зафиксировать в `lib/core/theme/telegram_theme.dart` (или аналог) единый набор констант.

#### Цвета (светлая тема)
- [x] Фон списка чатов: `#FFFFFF` / `#F0F0F0` (разделители)
- [x] Фон переписки: паттерн/градиент или однотонный `#E6EBEE` (как TG Android) / `#FFFFFF` (как TG Desktop)
- [x] Акцент / ссылки: `#3390EC` (классический Telegram blue)
- [x] Исходящий пузырь: `#EFFEDE` (светлая) / `#2B5278` (тёмная тема — исходящие)
- [x] Входящий пузырь: `#FFFFFF` (светлая) / `#182533` (тёмная)
- [x] Текст: primary `#000000` / `#FFFFFF`, secondary `#707579`, time `#8E8E93`

#### Цвета (тёмная тема)
- [x] Фон приложения: `#17212B`, список чатов `#17212B`, elevated `#232E3C`
- [x] Сохранить контраст WCAG AA для текста в пузырях

#### Типографика
- [x] Основной шрифт: **Roboto** (Android), **SF Pro** (iOS) — как у Telegram
- [ ] **Open Sans** на Desktop (Linux / Windows / macOS) — как у Telegram Desktop; сейчас системный sans
- [x] Размеры: заголовок чата 16sp semibold, текст сообщения 16sp, preview 14sp, время 12sp
- [x] Межстрочный интервал сообщений ~1.2–1.3

#### Скругления и тени
- [x] Пузыри: радиус 12–18px (больший у «хвоста»), **без** drop-shadow — плоский стиль
- [x] Аватары: круг 48px в списке, 40px в групповой ленте
- [x] Кнопки: pill radius 8px, primary filled `#3390EC`

#### Чего избегать (Liquid Glass и новый TG)
- [x] `BackdropFilter` / `ImageFilter.blur` для панелей и tab bar
- [x] Полупрозрачные «стеклянные» AppBar и нижняя навигация
- [x] Крупные скруглённые «капсулы» iOS 26 поверх всего экрана
- [x] Избыточные градиенты и neumorphism

---

### 9.2. Список чатов

- [x] Строка чата: аватар слева → колонка (имя + preview) → время и badge справа
- [x] Имя: semibold, одна строка, ellipsis
- [x] Preview: иконка типа медиа (микрофон, фото, видео) + текст, серая обрезка
- [x] Preview: галочки статуса доставки исходящего сообщения (✓ отправлено / ✓✓ прочитано) — `lastMessageDeliveryStatus` + `MessageDeliveryIcon` в `ChatListTile`
- [x] Время: uppercase не использовать, формат «14:32» / «вчера»
- [x] Badge непрочитанных: синий круг `#3390EC`, белый текст, min-width 20px
- [x] Mute: перечёркнутый колокольчик, сниженная opacity preview
- [x] Pin: иконка булавки, закреплённые сверху секции
- [x] Разделитель между чатами: 1px hairline, inset после аватара (как TG)
- [x] FAB «Новое сообщение»: синий круг с иконкой карандаша (mobile)
- [x] Поле поиска: скруглённое, фон `#F0F0F0`, без blur

---

### 9.3. Экран переписки

#### Шапка (AppBar)
- [x] Назад ← | аватар + имя + статус (online / last seen) | иконки поиск, меню
- [x] Фон шапки: сплошной цвет темы, **не** прозрачный blur
- [x] Подзаголовок: «был(а) недавно», «печатает…», «в сети» — 13sp secondary

#### Пузыри сообщений
- [x] Исходящие справа, входящие слева; max-width ~75% экрана
- [x] «Хвост» пузыря (tail) — опционально, как в мобильном TG
- [x] Время и галочки внутри пузыря, нижний правый угол, 11sp
- [x] Группировка: соседние сообщения одного отправителя — меньший отступ, скругление только с внешней стороны
- [x] Имя отправителя в группах: цветное, 13sp, над первым пузырём в серии
- [x] Цитата (reply): вертикальная полоса акцентного цвета, уменьшенный preview текста
- [x] Медиа без лишней рамки; caption под фото внутри того же пузыря

#### Фон чата
- [x] Опциональный wallpaper / doodle pattern (как в TG); дефолт — нейтральный серый/белый — `ChatWallpaper`
- [ ] Настройка пользовательского wallpaper в информации о чате (низкий приоритет)

#### Лента
- [x] Кнопка «↓ N новых сообщений» при скролле вверх
- [x] Дата-разделитель по центру: «15 августа», capsule `#00000026` на светлой теме
- [x] Плавный autoscroll при отправке своего сообщения

---

### 9.4. Панель ввода

- [x] Нижняя панель: сплошной фон, border-top 1px, **без** glass effect
- [x] Слева: вложения (скрепка) или эмодзи; справа: микрофон / send (синяя круглая кнопка при непустом тексте)
- [x] Поле ввода: скругление 20px, фон `#F0F0F0` / `#242F3D` (dark)
- [x] Placeholder «Сообщение» серым
- [x] Панель reply/edit над полем ввода: компактная полоса с крестиком отмены
- [x] Стикер/GIF панель: выезжает снизу, табы наборов, сетка 4–5 колонок

---

### 9.5. Навигация по платформам

#### Mobile (Android / iOS)
- [x] Нижний tab bar: **Чаты** | **Контакты** | **Настройки** (или drawer hamburger — как в выбранном референсе)
- [x] Tab bar: сплошной фон, иконки outline, активная вкладка — accent blue
- [x] iOS: без прозрачного UITabBar blur (если platform channel — `isTranslucent: false`)

#### Desktop (Windows / macOS / Linux)
- [x] Три колонки: узкая (папки/иконки) | список чатов ~340px | переписка flex
- [x] Минимальная ширина окна ~800px; при сужении — как mobile master-detail
- [x] Title bar: нативный или кастомный, без glass

#### Общее
- [x] Переходы: slide horizontal для push-экранов, fade 150–200ms
- [x] Ripple на Android, highlight на iOS — платформенные ink effects

---

### 9.6. Экраны настроек и профиля

- [x] Группы настроек в `ListView` с секционными заголовками (uppercase 12sp secondary)
- [x] Строка настройки: title слева, value/chevron справа, divider inset
- [x] Профиль сверху: большой аватар, имя, @username, телефон — как TG Settings
- [x] Переключатели: классический Material/Cupertino Switch, accent `#3390EC`
- [x] Экран прокси RioGram: встроить в стиль TG, не выбиваться визуально (см. §3)

---

### 9.7. Медиа, стикеры и спец-сообщения

- [x] Голосовое: горизонтальная waveform, кнопка play, длительность; исходящие — зеленоватый фон пузыря
- [x] Видео: превью с кнопкой play по центру, длительность в углу
- [x] Кружочек (video note): круглое превью 240px
- [x] Стикер: без пузыря (прозрачный фон), только тень не нужна
- [x] Документ: иконка типа файла + имя + размер в компактной карточке
- [x] Геолокация: статическая карта-превью со скруглением 8px
- [x] Полноэкранный viewer: чёрный фон, свайп между медиа, pinch-zoom

---

### 9.8. Звонки и уведомления

- [x] Входящий звонок: полноэкранный overlay, аватар, имя, зелёная «Принять» / красная «Отклонить»
- [x] Активный звонок: тёмный фон `#000000`, крупные круглые кнопки управления
- [x] Локальные уведомления: иконка приложения, стиль как системные (не кастомный glass banner)

---

### 9.9. Иконография и иллюстрации

- [x] Иконки: outline style, 24dp, единый stroke (Material Icons / Lucide — близко к TG)
- [x] Пустые состояния: SVG-иллюстрации (`assets/illustrations/`, `empty_state.dart`) («Нет чатов», «Выберите чат»)
- [x] Иконка приложения RioGram: launcher pipeline — [docs/APP_ICON.md](docs/APP_ICON.md), `flutter_launcher_icons`

---

### 9.10. План внедрения дизайна

| Этап | Экраны | Зависимости |
|------|--------|-------------|
| **D1** | Токены, светлая/тёмная тема, список чатов | §4.1 заменить/дополнить |
| **D2** | Переписка, пузыри, панель ввода | §4.2, §4.3 |
| **D3** | Настройки, профиль, прокси | §3.4 |
| **D4** | Контакты, инфо о чате, поиск | §6.5, §6.7, §6.8 |
| **D5** | Стикеры, звонки, stories UI | §6.4, §6.6, §6.12 |


### 9.11. Message bubble pixel parity (P1 #3–4, P2 #7–8)

- [x] Inline meta: время + галочки в последней строке текста (float-right spacer)
- [x] Bezier bubble tail вместо треугольника 6×10
- [x] Reply quote: tinted accent ~12%, radius 5px
- [x] Service messages: центрированная капсула `#00000033` / `#FFFFFF33`
- [x] Дата-разделитель: белый текст на `#0000004D` / `#FFFFFF33`
- [x] Delivered status: двойные серые галочки (`MessageDeliveryStatus.delivered`)

**Критерий готовности §9:** side-by-side скриншот RioGram и Telegram Desktop / Android — визуальное родство без blur/glass; пользователь узнаёт интерфейс за ≤5 секунд.

---

### 9.11. Визуальная полировка (pixel parity)

**Цель:** после §9.1–§9.10 довести отступы, размеры и микро-детали до side-by-side паритета с Telegram Desktop 4.x–5.x и Android (до Liquid Glass).  
**Метод:** сверка с [Telegram UI Kit](https://www.figma.com/community/file/867601279089856700) + скриншоты TG Desktop рядом с RioGram.  
**Регрессия:** `test/telegram_refinement_test.dart`, `test/date_separator_test.dart`, `test/message_delivery_icon_test.dart` (без Flutter golden — CI headless).

#### План внедрения §9.11

| Фаза | Область | PR / ветка | Результат |
|------|---------|------------|-----------|
| **R1** | Токены, шрифты, константы высот | `cursor/telegram-design-tokens-ca50` | Open Sans Desktop, `TelegramSpacing.chatListRowHeight` |
| **R2** | Список чатов | `cursor/telegram-refine-chat-list-ca50` | Галочки preview, row height 72px, typing в preview |
| **R3** | Переписка, фон | #91 wallpaper | Doodle/wallpaper, bubble tail, delivery icons |
| **R4** | Панель ввода | #89 input | Mic/send 48px, sticker panel height |
| **R5** | Аудит + скриншоты | этот PR + ручной чеклист | Side-by-side ≤5 сек узнаваемости |

#### 9.11.1. Дизайн-токены и типографика (доп. к §9.1)

- [ ] Open Sans на Desktop (см. §9.1)
- [x] Константа `TelegramSpacing.chatListRowHeight` = 72px и применение в `ChatListTile`
- [ ] Константа высоты AppBar переписки 56px (mobile)
- [x] Константа высоты строки настроек 48px (`TelegramSpacing.settingsRowHeight` + `TelegramSettingsTile`)
- [ ] Единый `TelegramSpacing.chatListHorizontalPadding` = 12px (сверка с TG)

#### 9.11.2. Список чатов (доп. к §9.2)

- [x] Галочки доставки в preview исходящих (✓ / ✓✓) — см. §9.2
- [ ] Индикатор «печатает…» / «записывает голосовое…» в preview
- [ ] Префикс имени отправителя в групповых чатах (`User:`)
- [ ] Вертикальное выравнение времени и badge при одной строке preview
- [ ] Hover / selected state на Desktop — цвет `#3390EC` @ 8% (сверка оттенка)
- [ ] FAB отступ снизу 16px + safe area (mobile)

#### 9.11.3. Экран переписки (доп. к §9.3)

- [x] Wallpaper / doodle pattern фона — #91 `ChatWallpaper`
- [x] `ChatWallpaper` виджет: pattern tile (blur для фото-обоев — позже)
- [ ] Bubble tail — SVG/path как в мобильном TG (сейчас упрощённый path)
- [x] Иконки доставки — `TelegramIcons` (#92: sent / delivered / read)
- [ ] Meta-строка (время + галочки) — baseline alignment в пузыре
- [ ] Link preview card: скругление, thumbnail, домен
- [ ] Service messages: центрированный серый текст без пузыря
- [ ] Кнопка «↓ N новых» — точный capsule radius и отступ от низа

#### 9.11.4. Панель ввода (доп. к §9.4)

- [ ] Touch target микрофона / send ≥ 48×48px
- [ ] Высота inline sticker panel ~320px (как TG Android)
- [x] Reply/edit strip — вертикальный accent bar 2px, отступы 8×12
- [x] Разделитель border-top: цвет divider темы, не `Colors.grey`

#### 9.11.5. Навигация (доп. к §9.5)

- [ ] Узкая колонка папок Desktop ~68px (иконки + tooltip)
- [ ] Resize handle между списком чатов и перепиской (Desktop)
- [ ] Tab bar label font 10sp / icon 24dp (mobile)

#### 9.11.6. Настройки и профиль (доп. к §9.6)

- [x] Строка настройки min-height 48px (`TelegramSettingsTile`, `TelegramSettingsSwitchTile`)
- [x] Секционный заголовок: top padding 24px, bottom 8px (`TelegramSettingsSectionHeader`)
- [x] Profile header avatar 120px на экране профиля (`TelegramSpacing.profileScreenAvatarRadius`)

#### 9.11.7. Медиа и спец-сообщения (доп. к §9.7)

- [ ] Voice waveform: 5px bars, gap 2px, 34 bars
- [ ] Video duration badge: padding 4×6, font 11sp
- [ ] Document card min-height 56px

#### 9.11.8. Звонки (доп. к §9.8)

- [ ] Incoming: пульсация вокруг зелёной кнопки «Принять» (опционально)
- [ ] Active call: spacing между кнопками 24px

#### 9.11.9. Регрессия и аудит

- [x] Unit/widget тесты констант и виджетов §9.11 (`telegram_refinement_test`, `date_separator_test`, `message_delivery_icon_test`)
- [ ] Ручной side-by-side чеклист: список чатов | переписка | ввод | настройки | звонок — [docs/SIDE_BY_SIDE_CHECKLIST.md](docs/SIDE_BY_SIDE_CHECKLIST.md)
- [x] Тёмная тема: второй проход pixel parity — widget-тесты
- [x] Desktop 800px / 840px breakpoints — `desktop_layout_regression_test.dart`

#### 9.11.10. Flat shell (устранение M3-утечек)

- [x] Desktop chat-list header без elevation (`chats_screen.dart`)
- [x] FAB elevation → 0 (`telegram_theme.dart`)
- [x] Кнопка «↓ N новых» без elevation (`scroll_to_bottom_button.dart`)
- [x] `ChatFolderSidebar`: цвета из `telegramTheme`, выделение — левая accent-полоса
- [x] `MessageReactionsRow`: компактные pill-чипы вместо `ActionChip`
- [x] `ChoiceChip` / `FilterChip` в chat UI → `TelegramFlatChip`

**Критерий готовности §9.11:** два скриншота (светлая + тёмная) RioGram и TG Desktop — отличия только в логотипе и уникальных RioGram-фишках; отступы и размеры в пределах ±2px.

#### 9.11.11. Типографика, аватары, polish настроек (P2 #11, P3 #18–19)

- [x] **Open Sans на Desktop** — `google_fonts`, `TelegramTypography.platformFontFamily` (Windows/Linux/macOS)
- [x] **Цветные placeholder-аватары** — `ChatAvatar` + `TelegramAvatarColors`
- [x] **Настройки desktop** — плоские группы на широких экранах (`telegram_settings_tile.dart`)

---

## ❗ Замечания

- Все изменения в TDLib помечены `// DPI_BYPASS:` — см. [docs/TDLIB_PATCHES.md](docs/TDLIB_PATCHES.md)
- API-ключи только в `.env`, не в коде
- Документация ведётся на русском в каталоге `docs/`
- Прокси: см. [docs/PROXY.md](docs/PROXY.md)
