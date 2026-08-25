import '../../models/chat_models.dart';

/// Причина сохранения снимка сообщения для анти-отзыва.
enum AntiRecallSnapshotReason {
  received,
  edited,
  deleted,
}

/// Локальная копия содержимого сообщения до редактирования/удаления.
class AntiRecallSnapshot {
  const AntiRecallSnapshot({
    required this.chatId,
    required this.messageId,
    required this.content,
    required this.capturedAt,
    required this.reason,
    this.senderName,
    this.isOutgoing = false,
    this.editDate,
  });

  final int chatId;
  final int messageId;
  final AntiRecallContent content;
  final DateTime capturedAt;
  final AntiRecallSnapshotReason reason;
  final String? senderName;
  final bool isOutgoing;
  final DateTime? editDate;

  factory AntiRecallSnapshot.fromMessage(
    ChatMessage message, {
    required AntiRecallSnapshotReason reason,
    required DateTime capturedAt,
    AntiRecallContent? preservedContent,
  }) {
    return AntiRecallSnapshot(
      chatId: message.chatId,
      messageId: message.id,
      content: preservedContent ??
          AntiRecallContent.fromMessageContent(message.content),
      capturedAt: capturedAt,
      reason: reason,
      senderName: message.senderName,
      isOutgoing: message.isOutgoing,
      editDate: message.editDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'chat_id': chatId,
        'message_id': messageId,
        'content': content.toJson(),
        'captured_at': capturedAt.toIso8601String(),
        'reason': reason.name,
        'sender_name': senderName,
        'is_outgoing': isOutgoing,
        'edit_date': editDate?.toIso8601String(),
      };

  factory AntiRecallSnapshot.fromJson(Map<String, dynamic> json) {
    return AntiRecallSnapshot(
      chatId: json['chat_id'] as int,
      messageId: json['message_id'] as int,
      content: AntiRecallContent.fromJson(
        json['content'] as Map<String, dynamic>,
      ),
      capturedAt: DateTime.parse(json['captured_at'] as String),
      reason: AntiRecallSnapshotReason.values.firstWhere(
        (item) => item.name == json['reason'],
        orElse: () => AntiRecallSnapshotReason.received,
      ),
      senderName: json['sender_name'] as String?,
      isOutgoing: json['is_outgoing'] as bool? ?? false,
      editDate: json['edit_date'] != null
          ? DateTime.tryParse(json['edit_date'] as String)
          : null,
    );
  }
}

/// Упрощённое содержимое для локального хранения анти-отзыва.
class AntiRecallContent {
  const AntiRecallContent({
    required this.kind,
    required this.preview,
    this.caption,
    this.fileName,
    this.localPath,
  });

  final MessageKind kind;
  final String preview;
  final String? caption;
  final String? fileName;
  final String? localPath;

  factory AntiRecallContent.fromMessageContent(MessageContent content) {
    return AntiRecallContent(
      kind: content.kind,
      preview: content.preview,
      caption: content.caption ?? content.formattedCaption?.text,
      fileName: content.fileName,
      localPath: content.localPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'preview': preview,
        'caption': caption,
        'file_name': fileName,
        'local_path': localPath,
      };

  factory AntiRecallContent.fromJson(Map<String, dynamic> json) {
    return AntiRecallContent(
      kind: MessageKind.values.firstWhere(
        (item) => item.name == json['kind'],
        orElse: () => MessageKind.text,
      ),
      preview: json['preview'] as String? ?? '',
      caption: json['caption'] as String?,
      fileName: json['file_name'] as String?,
      localPath: json['local_path'] as String?,
    );
  }
}
