# Децентрализация поверх Telegram (§7.6)

> **Статус:** исследование / долгосрочная дорожная карта.  
> RioGram остаётся **TDLib-first клиентом**; децентрализация рассматривается как
> надстройка, а не замена MTProto.

## Цель

Снизить зависимость пользователя от единой инфраструктуры Telegram DC, сохранив
совместимость с существующими чатами и ботами.

## Принципы

1. **Не ломать MTProto** — все текущие сценарии §6 продолжают работать через TDLib.
2. **Local-first** — пользователь владеет локальной копией данных (архив, медиа, anti-recall).
3. **Opt-in** — децентрализованные функции включаются явно.
4. **Постепенность** — research → prototype → pilot → production.

## Направления

### 1. Local-first архив (ближайший шаг)

Расширить существующие `AntiRecallStore` и `MediaCacheManager`:

- единая SQLite-схема `local_archive.db` per account;
- версионирование сообщений (edit/delete snapshots);
- экспорт в открытые форматы (JSON + media folder).

**Риски:** рост диска, миграции схемы.

### 2. P2P-оверлей между устройствами

Синхронизация локального архива между доверенными устройствами пользователя:

- WireGuard / Noise handshake;
- CRDT для метаданных чатов;
- медиа — через chunked sync.

**Не заменяет** Telegram cloud — только резервная копия и офлайн-доступ.

### 3. Мосты протоколов (Fediverse)

Односторонняя публикация из каналов RioGram:

```
RioGram channel post → RioGram relay service → ActivityPub actor
```

Клиент не хранит Fediverse credentials в TDLib session.

### 4. Федеративная идентичность

Mapping `telegram_user_id` ↔ внешний ключ (DID / PGP):

- верификация через подписанное сообщение в Saved Messages;
- отображение бейджа «verified external id» в профиле.

## Что **не** планируется в обозримом будущем

- Полная замена Telegram серверов собственным P2P-протоколом
- E2E поверх обычных групп без TDLib secret chats
- Автоматическая миграция истории в другой мессенджер

## Связь с §7.6 Plugin API

Плагины — точка расширения для экспериментов:

- `outgoing bridge` plugins (webhook post)
- `display` plugins для federated metadata
- будущий `archiveExport` capability

## Следующие шаги

| # | Задача | Фаза |
|---|--------|------|
| 1 | Спецификация `local_archive.db` | prototype |
| 2 | CLI export `riogram-archive-export` | prototype |
| 3 | Proof-of-concept ActivityPub relay | research |
| 4 | Security review P2P sync | research |

См. также `lib/models/decentralization_models.dart` — каталог для in-app экрана исследований.
