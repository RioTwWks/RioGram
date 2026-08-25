import '../../models/chat_models.dart';
import '../../models/search_models.dart';
import '../chat/tdlib_chat_parser.dart';
import '../tdlib/tdlib_json.dart';
import '../user/tdlib_user_parser.dart';

/// Парсинг TDLib search* ответов.
class TdlibSearchParser {
  const TdlibSearchParser._();

  static List<SearchMessageHit> parseFoundMessages(Map<String, dynamic>? json) {
    if (json == null || json['@type'] != 'foundMessages') {
      return const [];
    }
    return TdlibChatParser.parseFoundMessages(json);
  }

  static List<SearchMessageHit> parseFoundChatMessages(
    Map<String, dynamic>? json, {
    required int chatId,
    String? chatTitle,
  }) {
    if (json == null || json['@type'] != 'foundChatMessages') {
      return const [];
    }
    final messages = json['messages'] as List<dynamic>? ?? [];
    return messages.whereType<Map<String, dynamic>>().map((message) {
      final content = message['content'] as Map<String, dynamic>? ?? {};
      final dateSeconds = tdIntOr(message['date']);
      return SearchMessageHit(
        chatId: chatId,
        messageId: tdIntOr(message['id']),
        preview: MessageContent.fromTdlib(content).preview,
        date: DateTime.fromMillisecondsSinceEpoch(dateSeconds * 1000),
        chatTitle: chatTitle,
      );
    }).where((hit) => hit.messageId != 0).toList();
  }

  static String parseFoundMessagesNextOffset(Map<String, dynamic>? json) {
    if (json == null || json['@type'] != 'foundMessages') {
      return '';
    }
    return json['next_offset'] as String? ?? '';
  }

  static int parseFoundChatMessagesNextFromId(Map<String, dynamic>? json) {
    if (json == null || json['@type'] != 'foundChatMessages') {
      return 0;
    }
    return tdIntOr(json['next_from_message_id']);
  }

  static int parseTotalCount(Map<String, dynamic>? json) {
    if (json == null) {
      return 0;
    }
    return tdIntOr(json['total_count']);
  }

  static List<int> parseChatIds(Map<String, dynamic>? json) {
    if (json == null || json['@type'] != 'chats') {
      return const [];
    }
    return (json['chat_ids'] as List<dynamic>? ?? [])
        .map((id) => tdIntOr(id))
        .where((id) => id > 0)
        .toList();
  }

  static SearchUserHit? parseUserHit(Map<String, dynamic>? json) {
    final user = TdlibUserParser.parseUser(json);
    if (user == null) {
      return null;
    }
    return SearchUserHit(
      userId: user.id,
      displayName: user.displayName,
      username: user.username,
      isBot: user.isBot,
    );
  }

  static String? parsePhoneNumber(String query) {
    final trimmed = query.trim().replaceAll(' ', '').replaceAll('-', '');
    if (trimmed.isEmpty) {
      return null;
    }
    final normalized = trimmed.startsWith('+') ? trimmed : '+$trimmed';
    if (!RegExp(r'^\+\d{10,15}$').hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }

  static String? parseInviteToken(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed.startsWith('http') ? trimmed : 'https://$trimmed');
    if (uri != null &&
        (uri.host.contains('t.me') || uri.host.contains('telegram.me'))) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) {
        return null;
      }
      if (segments.first == 'joinchat' && segments.length > 1) {
        return segments[1];
      }
      if (segments.first.startsWith('+')) {
        return segments.first.substring(1);
      }
    }

    if (trimmed.startsWith('+') && trimmed.length > 8) {
      return trimmed.substring(1);
    }
    return null;
  }
}
