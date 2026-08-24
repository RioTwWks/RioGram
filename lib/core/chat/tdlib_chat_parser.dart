import '../../models/chat_models.dart';
import '../../models/group_models.dart';
import 'tdlib_chat_info_parser.dart';
import '../tdlib/tdlib_json.dart';

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

  static ChatSummary? parseChat(
    Map<String, dynamic> chat, {
    int? myUserId,
    Map<int, bool>? botUsers,
  }) {
    final id = tdInt(chat['id']);
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
      final dateSeconds = tdIntOr(lastMessage['date']);
      date = DateTime.fromMillisecondsSinceEpoch(dateSeconds * 1000);
    }

    final avatar = parseAvatar(chat['photo'] as Map<String, dynamic>?);
    final positions = parsePositions(chat['positions'] as List<dynamic>?);
    final notificationSettings =
        chat['notification_settings'] as Map<String, dynamic>?;
    final draftPreview = parseDraftPreview(chat['draft_message'] as Map<String, dynamic>?);
    final typeInfo = parseChatType(
      chat['type'] as Map<String, dynamic>?,
      myUserId: myUserId,
      botUsers: botUsers,
    );

    return ChatSummary(
      id: id,
      title: title,
      lastMessage: preview,
      lastMessageDate: date,
      unreadCount: tdIntOr(chat['unread_count']),
      avatarFileId: avatar.fileId,
      avatarLocalPath: avatar.localPath,
      kind: typeInfo.kind,
      positions: positions,
      isMuted: isChatMuted(notificationSettings),
      draftPreview: draftPreview,
      privateUserId: typeInfo.privateUserId,
      isMarkedAsUnread: chat['is_marked_as_unread'] as bool? ?? false,
      canBeDeletedOnlyForSelf:
          chat['can_be_deleted_only_for_self'] as bool? ?? true,
      canBeDeletedForAllUsers:
          chat['can_be_deleted_for_all_users'] as bool? ?? false,
      basicGroupId: typeInfo.basicGroupId,
      supergroupId: typeInfo.supergroupId,
      isForum: typeInfo.isForum ||
          (chat['view_as_topics'] as bool? ?? false),
      canSendMessages: TdlibChatInfoParser.parsePermissions(
        chat['permissions'] as Map<String, dynamic>?,
      ).canSendBasicMessages,
    );
  }

  static List<SearchMessageHit> parseFoundMessages(
    Map<String, dynamic> update,
  ) {
    final messages = update['messages'] as List<dynamic>? ?? [];
    return messages.whereType<Map<String, dynamic>>().map((message) {
      final content = message['content'] as Map<String, dynamic>? ?? {};
      final dateSeconds = tdIntOr(message['date']);
      return SearchMessageHit(
        chatId: tdIntOr(message['chat_id']),
        messageId: tdIntOr(message['id']),
        preview: MessageContent.fromTdlib(content).preview,
        date: DateTime.fromMillisecondsSinceEpoch(dateSeconds * 1000),
      );
    }).where((hit) => hit.chatId != 0 && hit.messageId != 0).toList();
  }

  static List<ChatPositionInfo> parsePositions(List<dynamic>? raw) {
    if (raw == null) {
      return const [];
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ChatPositionInfo.fromTdlib)
        .toList();
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

    final fileId = tdInt(fileInfo['id']);
    final local = fileInfo['local'] as Map<String, dynamic>?;
    final localPath = local != null && local['is_downloading_completed'] == true
        ? local['path'] as String?
        : null;

    return ChatAvatarData(fileId: fileId, localPath: localPath);
  }

  static ChatMessage? parseMessage(
    Map<String, dynamic> json, {
    int lastReadOutboxMessageId = 0,
  }) {
    if (json['@type'] != 'message') {
      return null;
    }
    return ChatMessage.fromTdlib(
      json,
      lastReadOutboxMessageId: lastReadOutboxMessageId,
    );
  }

  static String? parseTypingAction(Map<String, dynamic> update) {
    if (update['@type'] != 'updateUserChatAction') {
      return null;
    }
    final action = update['action'] as Map<String, dynamic>?;
    return switch (action?['@type']) {
      'chatActionTyping' => 'печатает…',
      'chatActionRecordingVoiceNote' => 'записывает голосовое…',
      'chatActionChoosingSticker' => 'выбирает стикер…',
      'chatActionRecordingVideoNote' => 'записывает видеосообщение…',
      'chatActionStartPlaying' => 'слушает голосовое…',
      _ => null,
    };
  }

  static int? parseFileId(Map<String, dynamic> content) {
    return MessageContent.parseMediaFileId(content);
  }

  static bool isChatMuted(Map<String, dynamic>? settings) {
    if (settings == null) {
      return false;
    }
    if (settings['use_default_mute_for'] as bool? ?? true) {
      return false;
    }
    final muteFor = tdIntOr(settings['mute_for']);
    return muteFor != 0;
  }

  static String? parseDraftPreview(Map<String, dynamic>? draft) {
    if (draft == null) {
      return null;
    }

    final content = draft['content'] as Map<String, dynamic>?;
    if (content == null) {
      return null;
    }

    return switch (content['@type']) {
      'draftMessageContentText' => _formattedText(content['text']),
      'draftMessageContentRichMessage' => _richMessagePreview(content['message']),
      'draftMessageContentVideoNote' => 'Видеосообщение',
      'draftMessageContentVoiceNote' => 'Голосовое сообщение',
      _ => null,
    };
  }

  static String? _formattedText(dynamic value) {
    if (value is Map<String, dynamic>) {
      final text = value['text'] as String?;
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  static String? _richMessagePreview(dynamic value) {
    if (value is Map<String, dynamic>) {
      final text = value['text'] as Map<String, dynamic>?;
      return _formattedText(text);
    }
    return null;
  }

  static ChatTypeInfo parseChatType(
    Map<String, dynamic>? type, {
    int? myUserId,
    Map<int, bool>? botUsers,
  }) {
    if (type == null) {
      return const ChatTypeInfo(kind: ChatKind.privateChat);
    }

    return switch (type['@type']) {
      'chatTypeBasicGroup' => ChatTypeInfo(
          kind: ChatKind.group,
          basicGroupId: tdInt(type['basic_group_id']),
        ),
      'chatTypeSupergroup' => ChatTypeInfo(
          kind: (type['is_channel'] as bool? ?? false)
              ? ChatKind.channel
              : ChatKind.group,
          supergroupId: tdInt(type['supergroup_id']),
        ),
      'chatTypeSecret' => const ChatTypeInfo(kind: ChatKind.secret),
      'chatTypePrivate' => () {
          final private = _parsePrivateChatType(
            tdInt(type['user_id']),
            myUserId: myUserId,
            botUsers: botUsers,
          );
          return ChatTypeInfo(
            kind: private.kind,
            privateUserId: private.privateUserId,
          );
        }(),
      _ => const ChatTypeInfo(kind: ChatKind.privateChat),
    };
  }

  static ({ChatKind kind, int? privateUserId}) _parsePrivateChatType(
    int? userId, {
    int? myUserId,
    Map<int, bool>? botUsers,
  }) {
    if (userId == null) {
      return (kind: ChatKind.privateChat, privateUserId: null);
    }
    if (myUserId != null && userId == myUserId) {
      return (kind: ChatKind.savedMessages, privateUserId: userId);
    }
    if (botUsers?[userId] == true) {
      return (kind: ChatKind.bot, privateUserId: userId);
    }
    return (kind: ChatKind.privateChat, privateUserId: userId);
  }

  static bool isBotUser(Map<String, dynamic> user) {
    final type = user['type'] as Map<String, dynamic>?;
    return type?['@type'] == 'userTypeBot';
  }

  static List<ChatFolderTab> parseChatFolders(Map<String, dynamic> update) {
    final folders = update['chat_folders'] as List<dynamic>? ?? [];
    return folders
        .whereType<Map<String, dynamic>>()
        .map((folder) {
          final nameRaw = folder['name'] as Map<String, dynamic>?;
          final name = nameRaw?['text'] as Map<String, dynamic>?;
          final title = name?['text'] as String? ?? 'Папка';
          final icon = folder['icon'] as Map<String, dynamic>?;
          return ChatFolderTab(
            id: tdIntOr(folder['id']),
            name: title,
            iconName: icon?['name'] as String?,
          );
        })
        .where((folder) => folder.id != 0)
        .toList();
  }

  static ChatKind resolvePrivateChatKind({
    required int userId,
    int? myUserId,
    required Map<int, bool> botUsers,
  }) {
    if (myUserId != null && userId == myUserId) {
      return ChatKind.savedMessages;
    }
    if (botUsers[userId] == true) {
      return ChatKind.bot;
    }
    return ChatKind.privateChat;
  }
}
