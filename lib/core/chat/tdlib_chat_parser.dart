import '../../models/chat_models.dart';

/// Данные аватара чата из TDLib chatPhotoInfo.
class ChatAvatarData {
  const ChatAvatarData({
    this.fileId,
    this.localPath,
  });

  final int? fileId;
  final String? localPath;
}

/// Парсинг TDLib-обновлений для чатов и сообщений.
class TdlibChatParser {
  const TdlibChatParser._();

  static ChatSummary? parseChat(Map<String, dynamic> chat) {
    final id = chat['id'] as int?;
    final title = chat['title'] as String?;
    if (id == null || title == null) {
      return null;
    }

    final lastMessage = chat['last_message'] as Map<String, dynamic>?;
    String? preview;
    DateTime? date;
    if (lastMessage != null) {
      final content = lastMessage['content'] as Map<String, dynamic>? ?? {};
      preview = MessageContent.fromTdlib(content).preview;
      final dateSeconds = lastMessage['date'] as int? ?? 0;
      date = DateTime.fromMillisecondsSinceEpoch(dateSeconds * 1000);
    }

    final avatar = parseAvatar(chat['photo'] as Map<String, dynamic>?);

    return ChatSummary(
      id: id,
      title: title,
      lastMessage: preview,
      lastMessageDate: date,
      unreadCount: chat['unread_count'] as int? ?? 0,
      avatarFileId: avatar.fileId,
      avatarLocalPath: avatar.localPath,
    );
  }

  static ChatAvatarData parseAvatar(Map<String, dynamic>? photo) {
    if (photo == null) {
      return const ChatAvatarData();
    }

    // big — чёткое фото; small — fallback.
    final fileInfo = photo['big'] as Map<String, dynamic>? ??
        photo['small'] as Map<String, dynamic>?;
    if (fileInfo == null) {
      return const ChatAvatarData();
    }

    final fileId = fileInfo['id'] as int?;
    final local = fileInfo['local'] as Map<String, dynamic>?;
    final localPath = local != null && local['is_downloading_completed'] == true
        ? local['path'] as String?
        : null;

    return ChatAvatarData(fileId: fileId, localPath: localPath);
  }

  static ChatMessage? parseMessage(Map<String, dynamic> json) {
    if (json['@type'] != 'message') {
      return null;
    }
    return ChatMessage.fromTdlib(json);
  }

  static String? parseTypingAction(Map<String, dynamic> update) {
    if (update['@type'] != 'updateUserChatAction') {
      return null;
    }
    final action = update['action'] as Map<String, dynamic>?;
    if (action?['@type'] == 'chatActionTyping') {
      return 'печатает…';
    }
    return null;
  }

  static int? parseFileId(Map<String, dynamic> content) {
    return MessageContent.parseMediaFileId(content);
  }
}
