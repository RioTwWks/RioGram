import 'audio_models.dart';
import 'formatted_text.dart';
import 'media_models.dart';
import 'message_enrichment.dart';

/// Тип содержимого сообщения.
enum MessageKind {
  text,
  photo,
  video,
  videoNote,
  voice,
  audio,
  document,
  poll,
  unsupported,
}

/// Тип чата для иконок в списке.
enum ChatKind {
  privateChat,
  group,
  channel,
  bot,
  secret,
  savedMessages,
}

/// Ссылка на список чатов TDLib.
sealed class ChatListKey {
  const ChatListKey();

  String get storageId;

  Map<String, dynamic> toTdlib();

  static ChatListKey fromTdlib(Map<String, dynamic> json) {
    return switch (json['@type']) {
      'chatListArchive' => const ChatListArchive(),
      'chatListFolder' => ChatListFolder(
          folderId: json['chat_folder_id'] as int? ?? 0,
        ),
      _ => const ChatListMain(),
    };
  }
}

/// Основной список чатов.
final class ChatListMain extends ChatListKey {
  const ChatListMain();

  @override
  String get storageId => 'main';

  @override
  Map<String, dynamic> toTdlib() => {'@type': 'chatListMain'};
}

/// Архив чатов.
final class ChatListArchive extends ChatListKey {
  const ChatListArchive();

  @override
  String get storageId => 'archive';

  @override
  Map<String, dynamic> toTdlib() => {'@type': 'chatListArchive'};
}

/// Папка чатов.
final class ChatListFolder extends ChatListKey {
  const ChatListFolder({required this.folderId});

  final int folderId;

  @override
  String get storageId => 'folder_$folderId';

  @override
  Map<String, dynamic> toTdlib() => {
        '@type': 'chatListFolder',
        'chat_folder_id': folderId,
      };
}

/// Позиция чата в конкретном списке.
class ChatPositionInfo {
  const ChatPositionInfo({
    required this.list,
    required this.order,
    required this.isPinned,
  });

  final ChatListKey list;
  final int order;
  final bool isPinned;

  factory ChatPositionInfo.fromTdlib(Map<String, dynamic> json) {
    final listRaw = json['list'] as Map<String, dynamic>? ?? {};
    return ChatPositionInfo(
      list: ChatListKey.fromTdlib(listRaw),
      order: json['order'] as int? ?? 0,
      isPinned: json['is_pinned'] as bool? ?? false,
    );
  }
}

/// Вкладка папки чатов из updateChatFolders.
class ChatFolderTab {
  const ChatFolderTab({
    required this.id,
    required this.name,
    this.iconName,
  });

  final int id;
  final String name;
  final String? iconName;

  ChatListKey get listKey => ChatListFolder(folderId: id);
}

/// Содержимое сообщения для отображения в UI.
class MessageContent {
  const MessageContent({
    required this.kind,
    required this.preview,
    this.formattedText,
    this.caption,
    this.formattedCaption,
    this.localPath,
    this.fileName,
    this.poll,
    this.videoInfo,
    this.voiceInfo,
    this.audioInfo,
    this.documentInfo,
    this.fileSizeBytes,
  });

  final MessageKind kind;
  final String preview;
  final FormattedText? formattedText;
  final String? caption;
  final FormattedText? formattedCaption;
  final String? localPath;
  final String? fileName;
  final PollContent? poll;
  final MediaVideoInfo? videoInfo;
  final VoiceNoteInfo? voiceInfo;
  final AudioTrackInfo? audioInfo;
  final DocumentFileInfo? documentInfo;
  final int? fileSizeBytes;

  factory MessageContent.fromTdlib(Map<String, dynamic> content) {
    final type = content['@type'] as String? ?? '';

    return switch (type) {
      'messageText' => () {
          final formatted = FormattedText.fromTdlib(
            content['text'] as Map<String, dynamic>?,
          );
          return MessageContent(
            kind: MessageKind.text,
            preview: formatted.preview,
            formattedText: formatted,
          );
        }(),
      'messagePhoto' => () {
          final captionFormatted = _optionalFormattedCaption(content['caption']);
          return MessageContent(
            kind: MessageKind.photo,
            preview: '📷 Фото',
            caption: captionFormatted?.preview,
            formattedCaption: captionFormatted,
            fileSizeBytes: _photoSize(content),
          );
        }(),
      'messageVideo' => () {
          final captionFormatted = _optionalFormattedCaption(content['caption']);
          final videoRaw = content['video'] as Map<String, dynamic>? ?? {};
          return MessageContent(
            kind: MessageKind.video,
            preview: '🎬 Видео',
            caption: captionFormatted?.preview,
            formattedCaption: captionFormatted,
            videoInfo: _parseVideoInfo(videoRaw),
            fileSizeBytes: _fileSize(videoRaw['video']),
          );
        }(),
      'messageVideoNote' => () {
          final note = content['video_note'] as Map<String, dynamic>? ?? {};
          return MessageContent(
            kind: MessageKind.videoNote,
            preview: '⭕ Видеосообщение',
            videoInfo: _parseVideoNoteInfo(note),
            fileSizeBytes: _fileSize(note['video']),
          );
        }(),
      'messageDocument' => () {
          final captionFormatted = _optionalFormattedCaption(content['caption']);
          return MessageContent(
            kind: MessageKind.document,
            preview: '📎 ${_documentName(content)}',
            fileName: _documentName(content),
            caption: captionFormatted?.preview,
            formattedCaption: captionFormatted,
            documentInfo: DocumentFileInfo.fromTdlib(content),
            fileSizeBytes: _documentSize(content),
          );
        }(),
      'messageVoiceNote' => () {
          final captionFormatted = _optionalFormattedCaption(content['caption']);
          final voiceNote = content['voice_note'] as Map<String, dynamic>? ?? {};
          return MessageContent(
            kind: MessageKind.voice,
            preview: '🎤 Голосовое',
            caption: captionFormatted?.preview,
            formattedCaption: captionFormatted,
            voiceInfo: VoiceNoteInfo.fromTdlib(voiceNote),
            fileSizeBytes: _fileSize(voiceNote['voice']),
          );
        }(),
      'messageAudio' => () {
          final captionFormatted = _optionalFormattedCaption(content['caption']);
          final audioRaw = content['audio'] as Map<String, dynamic>? ?? {};
          return MessageContent(
            kind: MessageKind.audio,
            preview: '🎵 ${audioRaw['title'] as String? ?? audioRaw['file_name'] as String? ?? 'Аудио'}',
            caption: captionFormatted?.preview,
            formattedCaption: captionFormatted,
            audioInfo: AudioTrackInfo.fromTdlib(audioRaw),
            fileSizeBytes: _fileSize(audioRaw['audio']),
          );
        }(),
      'messagePoll' => () {
          final poll = PollContent.fromTdlib(content);
          return MessageContent(
            kind: MessageKind.poll,
            preview: '📊 ${poll.question}',
            poll: poll,
          );
        }(),
      _ => MessageContent(
          kind: MessageKind.unsupported,
          preview: 'Сообщение ($type)',
        ),
    };
  }

  static FormattedText? _optionalFormattedCaption(dynamic value) {
    if (value is Map<String, dynamic>) {
      final formatted = FormattedText.fromTdlib(value);
      if (formatted.text.isNotEmpty) {
        return formatted;
      }
    }
    return null;
  }

  static String _documentName(Map<String, dynamic> content) {
    final document = content['document'] as Map<String, dynamic>?;
    final fileName = document?['file_name'] as String?;
    return fileName ?? 'Файл';
  }

  static int? parseMediaFileId(Map<String, dynamic> content) {
    final type = content['@type'] as String?;
    return switch (type) {
      'messagePhoto' => _photoFileId(content),
      'messageVideo' => _videoFileId(content),
      'messageVideoNote' => _videoNoteFileId(content),
      'messageVoiceNote' => _voiceNoteFileId(content),
      'messageAudio' => _audioFileId(content),
      'messageDocument' => _documentFileId(content),
      _ => null,
    };
  }

  static MediaVideoInfo? _parseVideoInfo(Map<String, dynamic> videoRaw) {
    if (videoRaw.isEmpty) {
      return null;
    }
    return MediaVideoInfo(
      durationSeconds: videoRaw['duration'] as int? ?? 0,
      width: videoRaw['width'] as int? ?? 0,
      height: videoRaw['height'] as int? ?? 0,
    );
  }

  static MediaVideoInfo? _parseVideoNoteInfo(Map<String, dynamic> note) {
    if (note.isEmpty) {
      return null;
    }
    final videoRaw = note['video'] as Map<String, dynamic>? ?? {};
    return MediaVideoInfo(
      durationSeconds: note['duration'] as int? ?? videoRaw['duration'] as int? ?? 0,
      width: note['length'] as int? ?? 0,
      height: note['length'] as int? ?? 0,
      videoNoteLength: note['length'] as int? ?? 0,
    );
  }

  static int? parseCoverFileId(Map<String, dynamic> content) {
    if (content['@type'] != 'messageAudio') {
      return null;
    }
    final audio = content['audio'] as Map<String, dynamic>? ?? {};
    final cover = audio['album_cover_thumbnail'] as Map<String, dynamic>?;
    final file = cover?['file'] as Map<String, dynamic>?;
    return file?['id'] as int?;
  }

  static int? _photoFileId(Map<String, dynamic> content) {
    final photo = content['photo'] as Map<String, dynamic>?;
    final sizes = photo?['sizes'] as List<dynamic>?;
    if (sizes == null || sizes.isEmpty) {
      return null;
    }
    final largest = sizes.last as Map<String, dynamic>;
    final photoSize = largest['photo'] as Map<String, dynamic>?;
    return photoSize?['id'] as int?;
  }

  static int? _videoFileId(Map<String, dynamic> content) {
    final video = content['video'] as Map<String, dynamic>?;
    final file = video?['video'] as Map<String, dynamic>?;
    return file?['id'] as int?;
  }

  static int? _videoNoteFileId(Map<String, dynamic> content) {
    final note = content['video_note'] as Map<String, dynamic>?;
    final file = note?['video'] as Map<String, dynamic>?;
    return file?['id'] as int?;
  }

  static int? _voiceNoteFileId(Map<String, dynamic> content) {
    final note = content['voice_note'] as Map<String, dynamic>?;
    final file = note?['voice'] as Map<String, dynamic>?;
    return file?['id'] as int?;
  }

  static int? _audioFileId(Map<String, dynamic> content) {
    final audio = content['audio'] as Map<String, dynamic>?;
    final file = audio?['audio'] as Map<String, dynamic>?;
    return file?['id'] as int?;
  }

  static int? _documentFileId(Map<String, dynamic> content) {
    final document = content['document'] as Map<String, dynamic>?;
    final file = document?['document'] as Map<String, dynamic>?;
    return file?['id'] as int?;
  }

  static int? _fileSize(dynamic fileJson) {
    if (fileJson is! Map<String, dynamic>) {
      return null;
    }
    return fileJson['expected_size'] as int? ?? fileJson['size'] as int?;
  }

  static int? _photoSize(Map<String, dynamic> content) {
    final photo = content['photo'] as Map<String, dynamic>?;
    final sizes = photo?['sizes'] as List<dynamic>?;
    if (sizes == null || sizes.isEmpty) {
      return null;
    }
    final largest = sizes.last as Map<String, dynamic>;
    final photoSize = largest['photo'] as Map<String, dynamic>?;
    return _fileSize(photoSize);
  }

  static int? _documentSize(Map<String, dynamic> content) {
    final document = content['document'] as Map<String, dynamic>? ?? {};
    return _fileSize(document['document']);
  }
}

/// Результат глобального поиска сообщений.
class SearchMessageHit {
  const SearchMessageHit({
    required this.chatId,
    required this.messageId,
    required this.preview,
    required this.date,
    this.chatTitle,
  });

  final int chatId;
  final int messageId;
  final String preview;
  final DateTime date;
  final String? chatTitle;

  SearchMessageHit copyWith({String? chatTitle}) {
    return SearchMessageHit(
      chatId: chatId,
      messageId: messageId,
      preview: preview,
      date: date,
      chatTitle: chatTitle ?? this.chatTitle,
    );
  }
}

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.title,
    this.lastMessage,
    this.lastMessageDate,
    this.unreadCount = 0,
    this.avatarFileId,
    this.avatarLocalPath,
    this.kind = ChatKind.privateChat,
    this.positions = const [],
    this.isMuted = false,
    this.draftPreview,
    this.privateUserId,
    this.isMarkedAsUnread = false,
    this.canBeDeletedOnlyForSelf = true,
    this.canBeDeletedForAllUsers = false,
  });

  final int id;
  final String title;
  final String? lastMessage;
  final DateTime? lastMessageDate;
  final int unreadCount;
  final int? avatarFileId;
  final String? avatarLocalPath;
  final ChatKind kind;
  final List<ChatPositionInfo> positions;
  final bool isMuted;
  final String? draftPreview;
  final int? privateUserId;
  final bool isMarkedAsUnread;
  final bool canBeDeletedOnlyForSelf;
  final bool canBeDeletedForAllUsers;

  /// Показывать индикатор непрочитанного (счётчик или метка).
  bool get showsUnreadIndicator => unreadCount > 0 || isMarkedAsUnread;

  /// Можно покинуть чат (группа / канал).
  bool get canLeave => kind == ChatKind.group || kind == ChatKind.channel;

  /// Текст превью: черновик имеет приоритет над последним сообщением.
  String? get previewText {
    final draft = draftPreview;
    if (draft != null && draft.isNotEmpty) {
      return 'Черновик: $draft';
    }
    return lastMessage;
  }

  ChatPositionInfo? positionIn(ChatListKey list) {
    for (final position in positions) {
      if (position.list.storageId == list.storageId) {
        return position;
      }
    }
    return null;
  }

  bool isInList(ChatListKey list) {
    final position = positionIn(list);
    return position != null && position.order != 0;
  }

  bool isPinnedIn(ChatListKey list) {
    return positionIn(list)?.isPinned ?? false;
  }

  ChatSummary copyWith({
    String? title,
    String? lastMessage,
    DateTime? lastMessageDate,
    int? unreadCount,
    int? avatarFileId,
    String? avatarLocalPath,
    ChatKind? kind,
    List<ChatPositionInfo>? positions,
    bool? isMuted,
    String? draftPreview,
    bool clearDraftPreview = false,
    int? privateUserId,
    bool? isMarkedAsUnread,
    bool? canBeDeletedOnlyForSelf,
    bool? canBeDeletedForAllUsers,
  }) {
    return ChatSummary(
      id: id,
      title: title ?? this.title,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageDate: lastMessageDate ?? this.lastMessageDate,
      unreadCount: unreadCount ?? this.unreadCount,
      avatarFileId: avatarFileId ?? this.avatarFileId,
      avatarLocalPath: avatarLocalPath ?? this.avatarLocalPath,
      kind: kind ?? this.kind,
      positions: positions ?? this.positions,
      isMuted: isMuted ?? this.isMuted,
      draftPreview: clearDraftPreview ? null : (draftPreview ?? this.draftPreview),
      privateUserId: privateUserId ?? this.privateUserId,
      isMarkedAsUnread: isMarkedAsUnread ?? this.isMarkedAsUnread,
      canBeDeletedOnlyForSelf:
          canBeDeletedOnlyForSelf ?? this.canBeDeletedOnlyForSelf,
      canBeDeletedForAllUsers:
          canBeDeletedForAllUsers ?? this.canBeDeletedForAllUsers,
    );
  }

  /// Сортировка чатов в списке: закреплённые сверху, затем по order.
  static int compareInList(ChatSummary a, ChatSummary b, ChatListKey list) {
    final posA = a.positionIn(list);
    final posB = b.positionIn(list);
    if (posA == null && posB == null) {
      return a.id.compareTo(b.id);
    }
    if (posA == null) {
      return 1;
    }
    if (posB == null) {
      return -1;
    }

    if (posA.isPinned != posB.isPinned) {
      return posA.isPinned ? -1 : 1;
    }

    final orderCompare = posB.order.compareTo(posA.order);
    if (orderCompare != 0) {
      return orderCompare;
    }
    return a.id.compareTo(b.id);
  }
}

class ChatMessage {
  /// Окно редактирования как в Telegram (48 часов).
  static const editWindow = Duration(hours: 48);

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.content,
    required this.date,
    required this.isOutgoing,
    this.senderName,
    this.localFilePath,
    this.mediaFileId,
    this.replyTo,
    this.forwardInfo,
    this.schedulingInfo,
    this.canBeEdited = false,
    this.canBeDeletedOnlyForSelf = true,
    this.canBeDeletedForAllUsers = false,
    this.editDate,
    this.isDeleted = false,
    this.deliveryStatus,
    this.interactionInfo,
    this.reactions = const [],
    this.inlineKeyboard = const [],
    this.groupedId,
    this.fileTransfer,
    this.coverFileId,
    this.coverLocalPath,
  });

  final int id;
  final int chatId;
  final MessageContent content;
  final DateTime date;
  final bool isOutgoing;
  final String? senderName;
  final String? localFilePath;
  final int? mediaFileId;
  final MessageReplyInfo? replyTo;
  final MessageForwardInfo? forwardInfo;
  final MessageSchedulingInfo? schedulingInfo;
  final bool canBeEdited;
  final bool canBeDeletedOnlyForSelf;
  final bool canBeDeletedForAllUsers;
  final DateTime? editDate;
  final bool isDeleted;
  final MessageDeliveryStatus? deliveryStatus;
  final MessageInteractionInfo? interactionInfo;
  final List<MessageReactionSummary> reactions;
  final List<List<InlineKeyboardButtonModel>> inlineKeyboard;
  final int? groupedId;
  final FileTransferState? fileTransfer;
  final int? coverFileId;
  final String? coverLocalPath;

  bool get isEdited => editDate != null;

  bool get canEditWithinWindow {
    if (!canBeEdited || isDeleted) {
      return false;
    }
    return DateTime.now().difference(date) <= editWindow;
  }

  bool get canEditText =>
      canEditWithinWindow && content.kind == MessageKind.text;

  bool get canEditCaption =>
      canEditWithinWindow &&
      (content.kind == MessageKind.photo ||
          content.kind == MessageKind.video ||
          content.kind == MessageKind.document ||
          content.kind == MessageKind.voice);

  String? get editableComposerText {
    if (content.kind == MessageKind.text) {
      return content.formattedText?.text ?? content.preview;
    }
    return content.formattedCaption?.text ?? content.caption;
  }

  ChatMessage copyWith({
    MessageContent? content,
    String? localFilePath,
    int? mediaFileId,
    MessageReplyInfo? replyTo,
    MessageForwardInfo? forwardInfo,
    MessageSchedulingInfo? schedulingInfo,
    bool? canBeEdited,
    bool? canBeDeletedOnlyForSelf,
    bool? canBeDeletedForAllUsers,
    DateTime? editDate,
    bool? isDeleted,
    MessageDeliveryStatus? deliveryStatus,
    MessageInteractionInfo? interactionInfo,
    List<MessageReactionSummary>? reactions,
    List<List<InlineKeyboardButtonModel>>? inlineKeyboard,
    int? groupedId,
    FileTransferState? fileTransfer,
    int? coverFileId,
    String? coverLocalPath,
    bool clearFileTransfer = false,
    bool clearCoverLocalPath = false,
  }) {
    return ChatMessage(
      id: id,
      chatId: chatId,
      content: content ?? this.content,
      date: date,
      isOutgoing: isOutgoing,
      senderName: senderName,
      localFilePath: localFilePath ?? this.localFilePath,
      mediaFileId: mediaFileId ?? this.mediaFileId,
      replyTo: replyTo ?? this.replyTo,
      forwardInfo: forwardInfo ?? this.forwardInfo,
      schedulingInfo: schedulingInfo ?? this.schedulingInfo,
      canBeEdited: canBeEdited ?? this.canBeEdited,
      canBeDeletedOnlyForSelf:
          canBeDeletedOnlyForSelf ?? this.canBeDeletedOnlyForSelf,
      canBeDeletedForAllUsers:
          canBeDeletedForAllUsers ?? this.canBeDeletedForAllUsers,
      editDate: editDate ?? this.editDate,
      isDeleted: isDeleted ?? this.isDeleted,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      interactionInfo: interactionInfo ?? this.interactionInfo,
      reactions: reactions ?? this.reactions,
      inlineKeyboard: inlineKeyboard ?? this.inlineKeyboard,
      groupedId: groupedId ?? this.groupedId,
      fileTransfer:
          clearFileTransfer ? null : (fileTransfer ?? this.fileTransfer),
      coverFileId: coverFileId ?? this.coverFileId,
      coverLocalPath:
          clearCoverLocalPath ? null : (coverLocalPath ?? this.coverLocalPath),
    );
  }

  factory ChatMessage.fromTdlib(
    Map<String, dynamic> json, {
    int lastReadOutboxMessageId = 0,
  }) {
    final dateSeconds = json['date'] as int? ?? 0;
    final contentMap = json['content'] as Map<String, dynamic>? ?? {};

    MessageReplyInfo? replyTo;
    final replyRaw = json['reply_to'] as Map<String, dynamic>?;
    if (replyRaw?['@type'] == 'messageReplyToMessage') {
      replyTo = MessageReplyInfo.fromTdlib(replyRaw);
    }

    MessageForwardInfo? forwardInfo;
    final forwardRaw = json['forward_info'] as Map<String, dynamic>?;
    if (forwardRaw != null) {
      forwardInfo = MessageForwardInfo.fromTdlib(forwardRaw);
    }

    MessageSchedulingInfo? schedulingInfo;
    final schedulingRaw = json['scheduling_state'] as Map<String, dynamic>?;
    if (schedulingRaw != null) {
      schedulingInfo = MessageSchedulingInfo.fromTdlib(schedulingRaw);
    }

    final editDateSeconds = json['edit_date'] as int? ?? 0;
    final editDate = editDateSeconds > 0
        ? DateTime.fromMillisecondsSinceEpoch(editDateSeconds * 1000)
        : null;

    return ChatMessage(
      id: json['id'] as int? ?? 0,
      chatId: json['chat_id'] as int? ?? 0,
      content: MessageContent.fromTdlib(contentMap),
      date: DateTime.fromMillisecondsSinceEpoch(dateSeconds * 1000),
      isOutgoing: json['is_outgoing'] as bool? ?? false,
      mediaFileId: MessageContent.parseMediaFileId(contentMap),
      coverFileId: MessageContent.parseCoverFileId(contentMap),
      replyTo: replyTo,
      forwardInfo: forwardInfo,
      schedulingInfo: schedulingInfo,
      canBeEdited: json['can_be_edited'] as bool? ?? false,
      canBeDeletedOnlyForSelf:
          json['can_be_deleted_only_for_self'] as bool? ?? true,
      canBeDeletedForAllUsers:
          json['can_be_deleted_for_all_users'] as bool? ?? false,
      editDate: editDate,
      deliveryStatus: MessageEnrichmentParser.parseDeliveryStatus(
        json,
        lastReadOutboxMessageId: lastReadOutboxMessageId,
      ),
      interactionInfo: MessageInteractionInfo.fromTdlib(
        json['interaction_info'] as Map<String, dynamic>?,
      ),
      reactions: MessageEnrichmentParser.parseReactions(
        json['reactions'] as Map<String, dynamic>?,
      ),
      inlineKeyboard: MessageEnrichmentParser.parseInlineKeyboard(
        json['reply_markup'] as Map<String, dynamic>?,
      ),
      groupedId: json['grouped_id'] as int?,
    );
  }
}
