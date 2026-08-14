/// Тип текстовой entity TDLib.
enum TextEntityKind {
  bold,
  italic,
  code,
  url,
  textUrl,
  mention,
  mentionName,
  hashtag,
}

/// Фрагмент форматирования в UTF-16 code units (как в TDLib).
class TextEntity {
  const TextEntity({
    required this.offset,
    required this.length,
    required this.kind,
    this.url,
    this.userId,
  });

  final int offset;
  final int length;
  final TextEntityKind kind;
  final String? url;
  final int? userId;

  factory TextEntity.fromTdlib(Map<String, dynamic> json) {
    final type = json['type'] as Map<String, dynamic>? ?? {};
    final kind = switch (type['@type']) {
      'textEntityTypeBold' => TextEntityKind.bold,
      'textEntityTypeItalic' => TextEntityKind.italic,
      'textEntityTypeCode' => TextEntityKind.code,
      'textEntityTypeUrl' => TextEntityKind.url,
      'textEntityTypeTextUrl' => TextEntityKind.textUrl,
      'textEntityTypeMention' => TextEntityKind.mention,
      'textEntityTypeMentionName' => TextEntityKind.mentionName,
      'textEntityTypeHashtag' => TextEntityKind.hashtag,
      _ => TextEntityKind.url,
    };

    return TextEntity(
      offset: json['offset'] as int? ?? 0,
      length: json['length'] as int? ?? 0,
      kind: kind,
      url: type['url'] as String?,
      userId: type['user_id'] as int?,
    );
  }

  Map<String, dynamic> toTdlib() {
    final type = switch (kind) {
      TextEntityKind.bold => {'@type': 'textEntityTypeBold'},
      TextEntityKind.italic => {'@type': 'textEntityTypeItalic'},
      TextEntityKind.code => {'@type': 'textEntityTypeCode'},
      TextEntityKind.url => {'@type': 'textEntityTypeUrl'},
      TextEntityKind.textUrl => {
          '@type': 'textEntityTypeTextUrl',
          'url': url ?? '',
        },
      TextEntityKind.mention => {'@type': 'textEntityTypeMention'},
      TextEntityKind.mentionName => {
          '@type': 'textEntityTypeMentionName',
          'user_id': userId ?? 0,
        },
      TextEntityKind.hashtag => {'@type': 'textEntityTypeHashtag'},
    };

    return {
      '@type': 'textEntity',
      'offset': offset,
      'length': length,
      'type': type,
    };
  }
}

/// Текст сообщения с entities (formattedText TDLib).
class FormattedText {
  const FormattedText({
    required this.text,
    this.entities = const [],
  });

  final String text;
  final List<TextEntity> entities;

  bool get isEmpty => text.isEmpty;

  factory FormattedText.fromTdlib(Map<String, dynamic>? json) {
    if (json == null) {
      return const FormattedText(text: '');
    }

    final text = json['text'] as String? ?? '';
    final rawEntities = json['entities'] as List<dynamic>? ?? [];
    final entities = rawEntities
        .whereType<Map<String, dynamic>>()
        .map(TextEntity.fromTdlib)
        .where((entity) => entity.length > 0)
        .toList()
      ..sort((a, b) => a.offset.compareTo(b.offset));

    return FormattedText(text: text, entities: entities);
  }

  Map<String, dynamic> toTdlib() => {
        '@type': 'formattedText',
        'text': text,
        'entities': entities.map((entity) => entity.toTdlib()).toList(),
      };

  /// Plain preview без markdown-разметки.
  String get preview => text;
}

/// Цитата ответа на сообщение.
class MessageReplyInfo {
  const MessageReplyInfo({
    required this.messageId,
    required this.preview,
    this.authorName,
  });

  final int messageId;
  final String preview;
  final String? authorName;

  factory MessageReplyInfo.fromTdlib(
    Map<String, dynamic>? json, {
    String? preview,
    String? authorName,
  }) {
    if (json == null) {
      throw ArgumentError('reply json is null');
    }

    return MessageReplyInfo(
      messageId: json['message_id'] as int? ?? 0,
      preview: preview ?? 'Сообщение',
      authorName: authorName,
    );
  }
}

/// Данные пересланного сообщения.
class MessageForwardInfo {
  const MessageForwardInfo({
    required this.originLabel,
    this.isHiddenOrigin = false,
  });

  final String originLabel;
  final bool isHiddenOrigin;

  factory MessageForwardInfo.fromTdlib(Map<String, dynamic>? json) {
    if (json == null) {
      throw ArgumentError('forward json is null');
    }

    final origin = json['origin'] as Map<String, dynamic>? ?? {};
    final type = origin['@type'] as String? ?? '';
    final isHidden = type == 'messageOriginHiddenUser' ||
        type == 'messageOriginChannel' && (origin['author_signature'] as String?)?.isEmpty == true;

    final label = switch (type) {
      'messageOriginUser' => 'Пользователь',
      'messageOriginHiddenUser' => 'Пересланное сообщение',
      'messageOriginChannel' => origin['author_signature'] as String? ?? 'Канал',
      'messageOriginChat' => 'Чат',
      _ => 'Переслано',
    };

    return MessageForwardInfo(
      originLabel: label,
      isHiddenOrigin: isHidden || type == 'messageOriginHiddenUser',
    );
  }
}

/// Отложенная отправка сообщения.
sealed class MessageSchedulingInfo {
  const MessageSchedulingInfo();

  factory MessageSchedulingInfo.fromTdlib(Map<String, dynamic>? json) {
    if (json == null) {
      throw ArgumentError('scheduling json is null');
    }

    return switch (json['@type']) {
      'messageSchedulingStateSendAtDate' => MessageSchedulingAtDate(
          sendAt: DateTime.fromMillisecondsSinceEpoch(
            (json['send_date'] as int? ?? 0) * 1000,
          ),
        ),
      'messageSchedulingStateSendWhenOnline' => const MessageSchedulingWhenOnline(),
      _ => MessageSchedulingAtDate(
          sendAt: DateTime.fromMillisecondsSinceEpoch(
            (json['send_date'] as int? ?? 0) * 1000,
          ),
        ),
    };
  }

  Map<String, dynamic> toTdlib();
}

final class MessageSchedulingAtDate extends MessageSchedulingInfo {
  const MessageSchedulingAtDate({required this.sendAt});

  final DateTime sendAt;

  @override
  Map<String, dynamic> toTdlib() => {
        '@type': 'messageSchedulingStateSendAtDate',
        'send_date': sendAt.millisecondsSinceEpoch ~/ 1000,
      };
}

final class MessageSchedulingWhenOnline extends MessageSchedulingInfo {
  const MessageSchedulingWhenOnline();

  @override
  Map<String, dynamic> toTdlib() => {
        '@type': 'messageSchedulingStateSendWhenOnline',
      };
}

/// Черновик ответа в composer.
class MessageReplyDraft {
  const MessageReplyDraft({
    required this.messageId,
    required this.preview,
    this.authorName,
  });

  final int messageId;
  final String preview;
  final String? authorName;
}

/// Черновик редактирования сообщения.
class MessageEditDraft {
  const MessageEditDraft({
    required this.messageId,
    required this.initialText,
    required this.isCaption,
  });

  final int messageId;
  final String initialText;
  final bool isCaption;
}

/// Тип исходящего chat action.
enum OutgoingChatAction {
  typing,
  recordingVoice,
  choosingSticker,
  cancel,
}
