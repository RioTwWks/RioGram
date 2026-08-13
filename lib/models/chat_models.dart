/// Тип содержимого сообщения.
enum MessageKind {
  text,
  photo,
  video,
  document,
  unsupported,
}

/// Содержимое сообщения для отображения в UI.
class MessageContent {
  const MessageContent({
    required this.kind,
    required this.preview,
    this.caption,
    this.localPath,
    this.fileName,
  });

  final MessageKind kind;
  final String preview;
  final String? caption;
  final String? localPath;
  final String? fileName;

  factory MessageContent.fromTdlib(Map<String, dynamic> content) {
    final type = content['@type'] as String? ?? '';

    return switch (type) {
      'messageText' => MessageContent(
          kind: MessageKind.text,
          preview: _formattedText(content['text']),
        ),
      'messagePhoto' => MessageContent(
          kind: MessageKind.photo,
          preview: '📷 Фото',
          caption: _optionalCaption(content['caption']),
        ),
      'messageVideo' => MessageContent(
          kind: MessageKind.video,
          preview: '🎬 Видео',
          caption: _optionalCaption(content['caption']),
        ),
      'messageDocument' => MessageContent(
          kind: MessageKind.document,
          preview: '📎 ${_documentName(content)}',
          fileName: _documentName(content),
          caption: _optionalCaption(content['caption']),
        ),
      _ => MessageContent(
          kind: MessageKind.unsupported,
          preview: 'Сообщение ($type)',
        ),
    };
  }

  static String _formattedText(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value['text'] as String? ?? '';
    }
    return '';
  }

  static String? _optionalCaption(dynamic value) {
    if (value is Map<String, dynamic>) {
      final text = value['text'] as String?;
      if (text != null && text.isNotEmpty) {
        return text;
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
      'messageDocument' => _documentFileId(content),
      _ => null,
    };
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

  static int? _documentFileId(Map<String, dynamic> content) {
    final document = content['document'] as Map<String, dynamic>?;
    final file = document?['document'] as Map<String, dynamic>?;
    return file?['id'] as int?;
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
  });

  final int id;
  final String title;
  final String? lastMessage;
  final DateTime? lastMessageDate;
  final int unreadCount;
  final int? avatarFileId;
  final String? avatarLocalPath;

  ChatSummary copyWith({
    String? title,
    String? lastMessage,
    DateTime? lastMessageDate,
    int? unreadCount,
    int? avatarFileId,
    String? avatarLocalPath,
  }) {
    return ChatSummary(
      id: id,
      title: title ?? this.title,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageDate: lastMessageDate ?? this.lastMessageDate,
      unreadCount: unreadCount ?? this.unreadCount,
      avatarFileId: avatarFileId ?? this.avatarFileId,
      avatarLocalPath: avatarLocalPath ?? this.avatarLocalPath,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.content,
    required this.date,
    required this.isOutgoing,
    this.senderName,
    this.localFilePath,
    this.mediaFileId,
  });

  final int id;
  final int chatId;
  final MessageContent content;
  final DateTime date;
  final bool isOutgoing;
  final String? senderName;
  final String? localFilePath;
  final int? mediaFileId;

  ChatMessage copyWith({
    MessageContent? content,
    String? localFilePath,
    int? mediaFileId,
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
    );
  }

  factory ChatMessage.fromTdlib(Map<String, dynamic> json) {
    final dateSeconds = json['date'] as int? ?? 0;
    final contentMap = json['content'] as Map<String, dynamic>? ?? {};
    return ChatMessage(
      id: json['id'] as int? ?? 0,
      chatId: json['chat_id'] as int? ?? 0,
      content: MessageContent.fromTdlib(contentMap),
      date: DateTime.fromMillisecondsSinceEpoch(dateSeconds * 1000),
      isOutgoing: json['is_outgoing'] as bool? ?? false,
      mediaFileId: MessageContent.parseMediaFileId(contentMap),
    );
  }
}
