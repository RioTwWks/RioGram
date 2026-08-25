/// Цель автопостинга в канал или бота.
class AutopostTarget {
  const AutopostTarget({
    required this.chatId,
    required this.title,
    this.enabled = false,
  });

  final int chatId;
  final String title;
  final bool enabled;

  AutopostTarget copyWith({
    int? chatId,
    String? title,
    bool? enabled,
  }) {
    return AutopostTarget(
      chatId: chatId ?? this.chatId,
      title: title ?? this.title,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'chat_id': chatId,
        'title': title,
        'enabled': enabled,
      };

  factory AutopostTarget.fromJson(Map<String, dynamic> json) {
    return AutopostTarget(
      chatId: json['chat_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  bool get isConfigured => chatId != 0 && title.isNotEmpty;
}

/// Настройки внешних интеграций RioGram.
class ExternalIntegrationsSettings {
  const ExternalIntegrationsSettings({
    this.autopostTarget = const AutopostTarget(chatId: 0, title: ''),
    this.mirrorOutgoingText = true,
  });

  final AutopostTarget autopostTarget;
  final bool mirrorOutgoingText;

  ExternalIntegrationsSettings copyWith({
    AutopostTarget? autopostTarget,
    bool? mirrorOutgoingText,
  }) {
    return ExternalIntegrationsSettings(
      autopostTarget: autopostTarget ?? this.autopostTarget,
      mirrorOutgoingText: mirrorOutgoingText ?? this.mirrorOutgoingText,
    );
  }

  Map<String, dynamic> toJson() => {
        'autopost_target': autopostTarget.toJson(),
        'mirror_outgoing_text': mirrorOutgoingText,
      };

  factory ExternalIntegrationsSettings.fromJson(Map<String, dynamic> json) {
    final target = json['autopost_target'];
    return ExternalIntegrationsSettings(
      autopostTarget: target is Map<String, dynamic>
          ? AutopostTarget.fromJson(target)
          : const AutopostTarget(chatId: 0, title: ''),
      mirrorOutgoingText: json['mirror_outgoing_text'] as bool? ?? true,
    );
  }
}
