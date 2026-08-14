import 'chat_models.dart';

/// Метаданные видео / видеосообщения.
class MediaVideoInfo {
  const MediaVideoInfo({
    required this.durationSeconds,
    this.width = 0,
    this.height = 0,
    this.videoNoteLength = 0,
  });

  final int durationSeconds;
  final int width;
  final int height;

  /// Диамeter кружочка (messageVideoNote.length).
  final int videoNoteLength;

  bool get isVideoNote => videoNoteLength > 0;

  String get durationLabel {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
    return '0:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Способ отправки медиа из composer.
enum MediaAttachAction {
  photoCompressed,
  photoAsFile,
  videoCompressed,
  videoAsFile,
  videoNote,
  audio,
  document,
  album,
}

/// Элемент списка переписки: одно сообщение или альбом.
sealed class ChatMessageListItem {
  const ChatMessageListItem();

  List<ChatMessage> get messages;
  ChatMessage get primary => messages.first;
}

final class SingleChatMessageItem extends ChatMessageListItem {
  const SingleChatMessageItem(this.message);

  final ChatMessage message;

  @override
  List<ChatMessage> get messages => [message];
}

final class AlbumChatMessageItem extends ChatMessageListItem {
  const AlbumChatMessageItem(this.albumMessages);

  final List<ChatMessage> albumMessages;

  @override
  List<ChatMessage> get messages => albumMessages;

  int? get groupedId =>
      albumMessages.isNotEmpty ? albumMessages.first.groupedId : null;
}

/// Группировка сообщений с общим grouped_id.
class MediaAlbumGrouper {
  const MediaAlbumGrouper._();

  static List<ChatMessageListItem> group(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      return const [];
    }

    final result = <ChatMessageListItem>[];
    var index = 0;
    while (index < messages.length) {
      final message = messages[index];
      final groupedId = message.groupedId;
      if (groupedId != null && groupedId != 0) {
        final album = <ChatMessage>[message];
        var next = index + 1;
        while (next < messages.length &&
            messages[next].groupedId == groupedId) {
          album.add(messages[next]);
          next++;
        }
        result.add(AlbumChatMessageItem(album));
        index = next;
      } else {
        result.add(SingleChatMessageItem(message));
        index++;
      }
    }
    return result;
  }

  static bool isMediaKind(MessageKind kind) {
    return kind == MessageKind.photo ||
        kind == MessageKind.video ||
        kind == MessageKind.videoNote;
  }
}

/// Элемент для полноэкранного просмотрщика.
class MediaViewerItem {
  const MediaViewerItem({
    required this.messageId,
    required this.kind,
    required this.localPath,
    this.caption,
    this.videoInfo,
  });

  final int messageId;
  final MessageKind kind;
  final String localPath;
  final String? caption;
  final MediaVideoInfo? videoInfo;

  factory MediaViewerItem.fromMessage(ChatMessage message) {
    final path = message.localFilePath ?? message.content.localPath;
    return MediaViewerItem(
      messageId: message.id,
      kind: message.content.kind,
      localPath: path ?? '',
      caption: message.content.caption,
      videoInfo: message.content.videoInfo,
    );
  }

  bool get hasLocalFile => localPath.isNotEmpty;
}
