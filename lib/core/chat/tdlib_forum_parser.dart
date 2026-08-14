import '../../models/chat_models.dart';
import '../../models/forum_models.dart';

/// Парсинг TDLib forumTopic / forumTopics.
class TdlibForumParser {
  const TdlibForumParser._();

  static List<ForumTopicSummary> parseForumTopics(Map<String, dynamic> json) {
    if (json['@type'] != 'forumTopics') {
      return const [];
    }
    final topics = json['topics'] as List<dynamic>? ?? [];
    return topics
        .whereType<Map<String, dynamic>>()
        .map(parseForumTopic)
        .whereType<ForumTopicSummary>()
        .toList()
      ..sort((a, b) => b.order.compareTo(a.order));
  }

  static ForumTopicsPageOffset parseForumTopicsOffset(Map<String, dynamic> json) {
    if (json['@type'] != 'forumTopics') {
      return const ForumTopicsPageOffset();
    }
    return ForumTopicsPageOffset(
      offsetDate: json['next_offset_date'] as int? ?? 0,
      offsetMessageId: json['next_offset_message_id'] as int? ?? 0,
      offsetForumTopicId: json['next_offset_forum_topic_id'] as int? ?? 0,
    );
  }

  static int? parseForumTopicsTotalCount(Map<String, dynamic> json) {
    if (json['@type'] != 'forumTopics') {
      return null;
    }
    return json['total_count'] as int?;
  }

  static ForumTopicSummary? parseForumTopic(Map<String, dynamic> json) {
    if (json['@type'] != 'forumTopic') {
      return null;
    }
    final info = json['info'] as Map<String, dynamic>?;
    if (info == null || info['@type'] != 'forumTopicInfo') {
      return null;
    }

    final forumTopicId = info['forum_topic_id'] as int? ?? 0;
    if (forumTopicId == 0) {
      return null;
    }

    String? preview;
    DateTime? date;
    final lastMessage = json['last_message'] as Map<String, dynamic>?;
    if (lastMessage != null) {
      final content = lastMessage['content'] as Map<String, dynamic>? ?? {};
      preview = MessageContent.fromTdlib(content).preview;
      final dateSeconds = lastMessage['date'] as int? ?? 0;
      if (dateSeconds > 0) {
        date = DateTime.fromMillisecondsSinceEpoch(dateSeconds * 1000);
      }
    }

    return ForumTopicSummary(
      forumTopicId: forumTopicId,
      name: info['name'] as String? ?? '',
      isGeneral: info['is_general'] as bool? ?? false,
      isClosed: info['is_closed'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      unreadCount: json['unread_count'] as int? ?? 0,
      lastMessagePreview: preview,
      lastMessageDate: date,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }

  static ForumTopicSummary? parseForumTopicInfo(Map<String, dynamic> json) {
    if (json['@type'] != 'forumTopicInfo') {
      return null;
    }
    final forumTopicId = json['forum_topic_id'] as int? ?? 0;
    if (forumTopicId == 0) {
      return null;
    }
    return ForumTopicSummary(
      forumTopicId: forumTopicId,
      name: json['name'] as String? ?? '',
      isGeneral: json['is_general'] as bool? ?? false,
      isClosed: json['is_closed'] as bool? ?? false,
    );
  }
}
