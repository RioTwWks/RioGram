import '../../models/chat_models.dart';
import '../../models/forum_models.dart';
import '../tdlib/tdlib_json.dart';

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
      offsetDate: tdIntOr(json['next_offset_date']),
      offsetMessageId: tdIntOr(json['next_offset_message_id']),
      offsetForumTopicId: tdIntOr(json['next_offset_forum_topic_id']),
    );
  }

  static int? parseForumTopicsTotalCount(Map<String, dynamic> json) {
    if (json['@type'] != 'forumTopics') {
      return null;
    }
    return tdInt(json['total_count']);
  }

  static ForumTopicSummary? parseForumTopic(Map<String, dynamic> json) {
    if (json['@type'] != 'forumTopic') {
      return null;
    }
    final info = json['info'] as Map<String, dynamic>?;
    if (info == null || info['@type'] != 'forumTopicInfo') {
      return null;
    }

    final forumTopicId = tdIntOr(info['forum_topic_id']);
    if (forumTopicId == 0) {
      return null;
    }

    String? preview;
    DateTime? date;
    final lastMessage = json['last_message'] as Map<String, dynamic>?;
    if (lastMessage != null) {
      final content = lastMessage['content'] as Map<String, dynamic>? ?? {};
      preview = MessageContent.fromTdlib(content).preview;
      final dateSeconds = tdIntOr(lastMessage['date']);
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
      unreadCount: tdIntOr(json['unread_count']),
      lastMessagePreview: preview,
      lastMessageDate: date,
      order: tdIntOr(json['order']),
    );
  }

  static ForumTopicSummary? parseForumTopicInfo(Map<String, dynamic> json) {
    if (json['@type'] != 'forumTopicInfo') {
      return null;
    }
    final forumTopicId = tdIntOr(json['forum_topic_id']);
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
