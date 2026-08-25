import '../../models/chat_models.dart';

/// Фильтрация рекламных чатов и сообщений (§7.4).
abstract final class AdBlockFilter {
  /// Максимальный server message id в TDLib: `int32.max << 20`.
  static const int maxServerMessageId = 2147483647 << 20;

  /// Верхняя граница id спонсорских сообщений: `1 << 51`.
  static const int maxSponsoredMessageId = 1 << 51;

  /// `TYPE_LOCAL` в младших 3 битах id сообщения.
  static const int sponsoredMessageTypeMask = 2;

  /// Спонсорский чат из MTProxy или рекламной выдачи.
  static bool isSponsoredChat(ChatSummary chat) {
    return chat.positions.any(
      (position) => position.source == ChatPositionSource.sponsored,
    );
  }

  /// Спонсорское сообщение в канале/боте (локальный id выше server max).
  static bool isSponsoredMessage(ChatMessage message) {
    final id = message.id;
    if (id <= maxServerMessageId || id > maxSponsoredMessageId) {
      return false;
    }
    return (id & 7) == sponsoredMessageTypeMask;
  }

  static List<ChatSummary> filterChats(List<ChatSummary> chats) {
    return chats.where((chat) => !isSponsoredChat(chat)).toList();
  }

  static List<ChatMessage> filterMessages(List<ChatMessage> messages) {
    return messages.where((message) => !isSponsoredMessage(message)).toList();
  }
}
