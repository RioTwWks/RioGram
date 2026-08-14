/// Статус доставки исходящего сообщения.
enum MessageDeliveryStatus {
  sending,
  sent,
  read,
  failed,
}

/// Просмотры и пересылки (каналы, посты).
class MessageInteractionInfo {
  const MessageInteractionInfo({
    this.viewCount = 0,
    this.forwardCount = 0,
    this.replyCount = 0,
  });

  final int viewCount;
  final int forwardCount;
  final int replyCount;

  factory MessageInteractionInfo.fromTdlib(Map<String, dynamic>? json) {
    if (json == null || json['@type'] != 'messageInteractionInfo') {
      return const MessageInteractionInfo();
    }
    final replyInfo = json['reply_info'] as Map<String, dynamic>?;
    return MessageInteractionInfo(
      viewCount: json['view_count'] as int? ?? 0,
      forwardCount: json['forward_count'] as int? ?? 0,
      replyCount: replyInfo?['reply_count'] as int? ?? 0,
    );
  }
}

/// Реакция на сообщение.
class MessageReactionSummary {
  const MessageReactionSummary({
    required this.emoji,
    required this.count,
    this.isChosen = false,
  });

  final String emoji;
  final int count;
  final bool isChosen;

  Map<String, dynamic> toReactionType() => {
        '@type': 'reactionTypeEmoji',
        'emoji': emoji,
      };
}

/// Кнопка inline-клавиатуры.
class InlineKeyboardButtonModel {
  const InlineKeyboardButtonModel({
    required this.text,
    this.url,
    this.callbackData,
  });

  final String text;
  final String? url;
  final String? callbackData;
}

/// Вариант ответа в опросе.
class PollOptionModel {
  const PollOptionModel({
    required this.id,
    required this.text,
    required this.voterCount,
    required this.votePercentage,
    this.isChosen = false,
  });

  final int id;
  final String text;
  final int voterCount;
  final double votePercentage;
  final bool isChosen;
}

/// Тип опроса.
enum PollKind {
  regular,
  quiz,
}

/// Данные опроса из messagePoll.
class PollContent {
  const PollContent({
    required this.question,
    required this.options,
    required this.totalVoterCount,
    required this.isClosed,
    required this.isAnonymous,
    required this.kind,
    this.correctOptionId,
  });

  final String question;
  final List<PollOptionModel> options;
  final int totalVoterCount;
  final bool isClosed;
  final bool isAnonymous;
  final PollKind kind;
  final int? correctOptionId;

  factory PollContent.fromTdlib(Map<String, dynamic> content) {
    final poll = content['poll'] as Map<String, dynamic>? ?? {};
    final questionRaw = poll['question'] as Map<String, dynamic>? ?? {};
    final question = questionRaw['text'] as String? ?? 'Опрос';

    final optionsRaw = poll['options'] as List<dynamic>? ?? [];
    final options = <PollOptionModel>[];
    for (var i = 0; i < optionsRaw.length; i++) {
      final option = optionsRaw[i] as Map<String, dynamic>? ?? {};
      final textRaw = option['text'] as Map<String, dynamic>? ?? {};
      options.add(
        PollOptionModel(
          id: i,
          text: textRaw['text'] as String? ?? 'Вариант ${i + 1}',
          voterCount: option['voter_count'] as int? ?? 0,
          votePercentage: (option['vote_percentage'] as num? ?? 0).toDouble(),
          isChosen: option['is_chosen'] as bool? ?? false,
        ),
      );
    }

    final type = poll['type'] as Map<String, dynamic>? ?? {};
    final isQuiz = type['@type'] == 'pollTypeQuiz';

    return PollContent(
      question: question,
      options: options,
      totalVoterCount: poll['total_voter_count'] as int? ?? 0,
      isClosed: poll['is_closed'] as bool? ?? false,
      isAnonymous: poll['is_anonymous'] as bool? ?? true,
      kind: isQuiz ? PollKind.quiz : PollKind.regular,
      correctOptionId:
          isQuiz ? type['correct_option_id'] as int? : null,
    );
  }
}

/// Парсинг дополнительных полей TDLib message.
class MessageEnrichmentParser {
  const MessageEnrichmentParser._();

  static MessageDeliveryStatus? parseDeliveryStatus(
    Map<String, dynamic> json, {
    required int lastReadOutboxMessageId,
  }) {
    if (!(json['is_outgoing'] as bool? ?? false)) {
      return null;
    }

    final sendingState = json['sending_state'] as Map<String, dynamic>?;
    if (sendingState != null) {
      return switch (sendingState['@type']) {
        'messageSendingStatePending' => MessageDeliveryStatus.sending,
        'messageSendingStateFailed' => MessageDeliveryStatus.failed,
        _ => MessageDeliveryStatus.sent,
      };
    }

    final messageId = json['id'] as int? ?? 0;
    if (messageId > 0 &&
        lastReadOutboxMessageId > 0 &&
        messageId <= lastReadOutboxMessageId) {
      return MessageDeliveryStatus.read;
    }

    return MessageDeliveryStatus.sent;
  }

  static List<MessageReactionSummary> parseReactions(
    Map<String, dynamic>? json,
  ) {
    if (json == null || json['@type'] != 'messageReactions') {
      return const [];
    }

    final raw = json['reactions'] as List<dynamic>? ?? [];
    return raw.whereType<Map<String, dynamic>>().map((reaction) {
      final type = reaction['type'] as Map<String, dynamic>? ?? {};
      return MessageReactionSummary(
        emoji: type['emoji'] as String? ?? '👍',
        count: reaction['total_count'] as int? ?? 0,
        isChosen: reaction['is_chosen'] as bool? ?? false,
      );
    }).toList();
  }

  static List<List<InlineKeyboardButtonModel>> parseInlineKeyboard(
    Map<String, dynamic>? markup,
  ) {
    if (markup == null || markup['@type'] != 'replyMarkupInlineKeyboard') {
      return const [];
    }

    final rows = markup['rows'] as List<dynamic>? ?? [];
    return rows.map((row) {
      final buttons = row as List<dynamic>? ?? [];
      return buttons.whereType<Map<String, dynamic>>().map((button) {
        final type = button['type'] as Map<String, dynamic>? ?? {};
        final typeName = type['@type'] as String? ?? '';
        return InlineKeyboardButtonModel(
          text: button['text'] as String? ?? '',
          url: typeName == 'inlineKeyboardButtonTypeUrl'
              ? type['url'] as String?
              : null,
          callbackData: typeName == 'inlineKeyboardButtonTypeCallback'
              ? type['data'] as String?
              : null,
        );
      }).toList();
    }).toList();
  }
}
