/// Фаза исследования децентрализованной модели RioGram.
enum DecentralizationPhase {
  research,
  prototype,
  pilot,
  production,
}

/// Направление исследования.
enum DecentralizationTrack {
  federation,
  p2pOverlay,
  localFirstArchive,
  bridgeProtocols,
}

/// Запись дорожной карты децентрализации.
class DecentralizationRoadmapItem {
  const DecentralizationRoadmapItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.track,
    required this.phase,
    required this.risks,
    this.dependencies = const [],
  });

  final String id;
  final String title;
  final String summary;
  final DecentralizationTrack track;
  final DecentralizationPhase phase;
  final List<String> risks;
  final List<String> dependencies;
}

/// Статический каталог исследований §7.6 (долгосрочно).
abstract final class DecentralizationResearchCatalog {
  static const List<DecentralizationRoadmapItem> items = [
    DecentralizationRoadmapItem(
      id: 'fed-activitypub-bridge',
      title: 'Мост ActivityPub ↔ Telegram',
      summary:
          'Исследовать одностороннюю публикацию из каналов RioGram в Fediverse '
          'без изменения MTProto. Клиент остаётся TDLib-first.',
      track: DecentralizationTrack.bridgeProtocols,
      phase: DecentralizationPhase.research,
      risks: [
        'Потеря end-to-end гарантий при экспорте',
        'Юридические ограничения на републикацию контента',
      ],
      dependencies: ['Стабильный экспорт медиа', 'OAuth/Webhook инфраструктура'],
    ),
    DecentralizationRoadmapItem(
      id: 'p2p-offline-sync',
      title: 'P2P-оверлей для офлайн-реплик',
      summary:
          'Локальные реплики чатов между доверенными устройствами через '
          'шифрованный sync (без замены Telegram DC).',
      track: DecentralizationTrack.p2pOverlay,
      phase: DecentralizationPhase.research,
      risks: [
        'Конфликты версий сообщений',
        'Высокая сложность key management',
      ],
    ),
    DecentralizationRoadmapItem(
      id: 'local-first-archive',
      title: 'Local-first архив переписок',
      summary:
          'Расширить Anti-Recall и media cache до полноценного локального '
          'архива с CRDT-метаданными для будущей синхронизации.',
      track: DecentralizationTrack.localFirstArchive,
      phase: DecentralizationPhase.prototype,
      risks: ['Рост дискового потребления', 'Миграции схемы SQLite'],
      dependencies: ['Anti-Recall store', 'Media cache manager'],
    ),
    DecentralizationRoadmapItem(
      id: 'identity-federation',
      title: 'Федеративная идентичность поверх Telegram ID',
      summary:
          'Слой mapping Telegram user_id ↔ внешние DID/ключи для '
          'межсервисной верификации без смены протокола.',
      track: DecentralizationTrack.federation,
      phase: DecentralizationPhase.research,
      risks: [
        'Фишинг при привязке внешних идентификаторов',
        'Нет официального API для DID в TDLib',
      ],
    ),
  ];

  static List<DecentralizationRoadmapItem> byTrack(DecentralizationTrack track) {
    return items.where((item) => item.track == track).toList();
  }

  static String trackLabel(DecentralizationTrack track) {
    return switch (track) {
      DecentralizationTrack.federation => 'Федерация',
      DecentralizationTrack.p2pOverlay => 'P2P-оверлей',
      DecentralizationTrack.localFirstArchive => 'Local-first архив',
      DecentralizationTrack.bridgeProtocols => 'Мосты протоколов',
    };
  }

  static String phaseLabel(DecentralizationPhase phase) {
    return switch (phase) {
      DecentralizationPhase.research => 'Исследование',
      DecentralizationPhase.prototype => 'Прототип',
      DecentralizationPhase.pilot => 'Пилот',
      DecentralizationPhase.production => 'Продакшен',
    };
  }
}
