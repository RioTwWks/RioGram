import '../core/tdlib/tdlib_json.dart';

/// Состояние секретного чата TDLib.
enum SecretChatStateKind {
  pending,
  ready,
  closed,
  unknown,
}

/// Данные секретного чата.
class SecretChatSummary {
  const SecretChatSummary({
    required this.id,
    required this.userId,
    this.state = SecretChatStateKind.unknown,
    this.isOutbound = false,
    this.keyHash = '',
    this.layer = 0,
  });

  final int id;
  final int userId;
  final SecretChatStateKind state;
  final bool isOutbound;
  final String keyHash;
  final int layer;

  bool get isReady => state == SecretChatStateKind.ready;

  SecretChatSummary copyWith({
    SecretChatStateKind? state,
    String? keyHash,
    int? layer,
  }) {
    return SecretChatSummary(
      id: id,
      userId: userId,
      state: state ?? this.state,
      isOutbound: isOutbound,
      keyHash: keyHash ?? this.keyHash,
      layer: layer ?? this.layer,
    );
  }
}

/// Предустановки таймера самоуничтожения (секретные чаты).
enum SecretChatTtlPreset {
  off,
  fiveSeconds,
  tenSeconds,
  thirtySeconds,
  oneMinute,
  oneHour,
  oneDay,
  oneWeek,
}

extension SecretChatTtlPresetX on SecretChatTtlPreset {
  int get seconds => switch (this) {
        SecretChatTtlPreset.off => 0,
        SecretChatTtlPreset.fiveSeconds => 5,
        SecretChatTtlPreset.tenSeconds => 10,
        SecretChatTtlPreset.thirtySeconds => 30,
        SecretChatTtlPreset.oneMinute => 60,
        SecretChatTtlPreset.oneHour => 3600,
        SecretChatTtlPreset.oneDay => 86400,
        SecretChatTtlPreset.oneWeek => 604800,
      };

  String get label => switch (this) {
        SecretChatTtlPreset.off => 'Выкл.',
        SecretChatTtlPreset.fiveSeconds => '5 сек.',
        SecretChatTtlPreset.tenSeconds => '10 сек.',
        SecretChatTtlPreset.thirtySeconds => '30 сек.',
        SecretChatTtlPreset.oneMinute => '1 мин.',
        SecretChatTtlPreset.oneHour => '1 час',
        SecretChatTtlPreset.oneDay => '1 день',
        SecretChatTtlPreset.oneWeek => '1 неделя',
      };

  static SecretChatTtlPreset fromSeconds(int seconds) {
    return switch (seconds) {
      <= 0 => SecretChatTtlPreset.off,
      <= 5 => SecretChatTtlPreset.fiveSeconds,
      <= 10 => SecretChatTtlPreset.tenSeconds,
      <= 30 => SecretChatTtlPreset.thirtySeconds,
      <= 60 => SecretChatTtlPreset.oneMinute,
      <= 3600 => SecretChatTtlPreset.oneHour,
      <= 86400 => SecretChatTtlPreset.oneDay,
      _ => SecretChatTtlPreset.oneWeek,
    };
  }

  Map<String, dynamic>? toSelfDestructType() {
    if (this == SecretChatTtlPreset.off) {
      return null;
    }
    return {
      '@type': 'messageSelfDestructTypeTimer',
      'self_destruct_time': seconds,
    };
  }
}

/// Парсинг секретных чатов TDLib.
class SecretChatJson {
  static SecretChatSummary parseSecretChat(Map<String, dynamic> json) {
    final stateType =
        (json['state'] as Map<String, dynamic>?)?['@type'] as String?;
    final state = switch (stateType) {
      'secretChatStatePending' => SecretChatStateKind.pending,
      'secretChatStateReady' => SecretChatStateKind.ready,
      'secretChatStateClosed' => SecretChatStateKind.closed,
      _ => SecretChatStateKind.unknown,
    };
    return SecretChatSummary(
      id: tdIntOr(json['id']),
      userId: tdIntOr(json['user_id']),
      state: state,
      isOutbound: json['is_outbound'] as bool? ?? false,
      keyHash: _bytesToEmojiKey(json['key_hash']),
      layer: tdIntOr(json['layer']),
    );
  }

  static String _bytesToEmojiKey(dynamic value) {
    if (value is! String || value.isEmpty) {
      return '';
    }
    final bytes = value.codeUnits.take(16);
    const emojis = ['🔑', '🗝️', '🔐', '🛡️', '✨', '⭐', '🌟', '💫'];
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(emojis[byte % emojis.length]);
    }
    return buffer.toString();
  }
}
