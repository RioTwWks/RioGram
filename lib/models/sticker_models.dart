import 'chat_models.dart';
import 'formatted_text.dart';

/// Модель стикера TDLib.
class StickerModel {
  const StickerModel({
    required this.fileId,
    required this.setId,
    required this.width,
    required this.height,
    required this.emoji,
    this.thumbnailFileId,
    this.isAnimated = false,
    this.isVideo = false,
  });

  final int fileId;
  final int setId;
  final int width;
  final int height;
  final String emoji;
  final int? thumbnailFileId;
  final bool isAnimated;
  final bool isVideo;

  factory StickerModel.fromTdlib(Map<String, dynamic> json) {
    final stickerFile = json['sticker'] as Map<String, dynamic>? ?? {};
    final thumbnail = json['thumbnail'] as Map<String, dynamic>?;
    final thumbFile = thumbnail?['file'] as Map<String, dynamic>?;
    final format = json['format'] as Map<String, dynamic>? ?? {};
    final formatType = format['@type'] as String? ?? '';

    return StickerModel(
      fileId: stickerFile['id'] as int? ?? 0,
      setId: json['set_id'] as int? ?? 0,
      width: json['width'] as int? ?? 512,
      height: json['height'] as int? ?? 512,
      emoji: json['emoji'] as String? ?? '🙂',
      thumbnailFileId: thumbFile?['id'] as int?,
      isAnimated: formatType == 'stickerFormatTgs',
      isVideo: formatType == 'stickerFormatWebm',
    );
  }

  Map<String, dynamic> toInputFileId() => {
        '@type': 'inputFileId',
        'id': fileId,
      };

  Map<String, dynamic> toInputStickerPayload() {
    final thumbId = thumbnailFileId ?? fileId;
    return {
      '@type': 'inputSticker',
      'sticker': toInputFileId(),
      'thumbnail': {
        '@type': 'inputThumbnail',
        'thumbnail': {
          '@type': 'inputFileId',
          'id': thumbId,
        },
        'width': width,
        'height': height,
      },
      'width': width,
      'height': height,
    };
  }

  Map<String, dynamic> toInputMessageSticker() => {
        '@type': 'inputMessageSticker',
        'sticker': toInputStickerPayload(),
        'emoji': emoji,
      };
}

/// Краткая информация о стикерпаке.
class StickerSetSummary {
  const StickerSetSummary({
    required this.id,
    required this.title,
    required this.name,
    this.count = 0,
    this.isInstalled = true,
    this.isArchived = false,
  });

  final int id;
  final String title;
  final String name;
  final int count;
  final bool isInstalled;
  final bool isArchived;

  factory StickerSetSummary.fromTdlib(Map<String, dynamic> json) {
    return StickerSetSummary(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Набор',
      name: json['name'] as String? ?? '',
      count: (json['stickers'] as List<dynamic>?)?.length ??
          json['count'] as int? ??
          0,
      isInstalled: json['is_installed'] as bool? ?? true,
      isArchived: json['is_archived'] as bool? ?? false,
    );
  }

  factory StickerSetSummary.fromStickerSetInfo(Map<String, dynamic> json) {
    final set = json['set'] as Map<String, dynamic>? ?? json;
    return StickerSetSummary.fromTdlib(set);
  }
}

/// GIF / animation из messageAnimation или inline-результата.
class AnimationModel {
  const AnimationModel({
    required this.fileId,
    required this.width,
    required this.height,
    required this.durationSeconds,
    this.fileName,
    this.mimeType,
    this.thumbnailFileId,
  });

  final int fileId;
  final int width;
  final int height;
  final int durationSeconds;
  final String? fileName;
  final String? mimeType;
  final int? thumbnailFileId;

  factory AnimationModel.fromTdlib(Map<String, dynamic> json) {
    final animationFile = json['animation'] as Map<String, dynamic>? ?? {};
    final thumbnail = json['thumbnail'] as Map<String, dynamic>?;
    final thumbFile = thumbnail?['file'] as Map<String, dynamic>?;

    return AnimationModel(
      fileId: animationFile['id'] as int? ?? 0,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      durationSeconds: json['duration'] as int? ?? 0,
      fileName: json['file_name'] as String?,
      mimeType: json['mime_type'] as String?,
      thumbnailFileId: thumbFile?['id'] as int?,
    );
  }

  Map<String, dynamic> toInputFileId() => {
        '@type': 'inputFileId',
        'id': fileId,
      };

  Map<String, dynamic> toInputMessageAnimation({FormattedText? caption}) => {
        '@type': 'inputMessageAnimation',
        'animation': toInputFileId(),
        if (caption != null && caption.text.isNotEmpty)
          'caption': caption.toTdlib(),
        'show_caption_above_media': false,
        'has_spoiler': false,
      };

  String get durationLabel {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}

/// Inline GIF-результат (@gif bot).
class GifSearchResult {
  const GifSearchResult({
    required this.resultId,
    required this.queryId,
    required this.title,
    required this.animation,
  });

  final String resultId;
  final int queryId;
  final String title;
  final AnimationModel animation;
}

/// Данные стикера/анимации в сообщении.
class StickerMessageInfo {
  const StickerMessageInfo({
    required this.sticker,
    this.emoji,
  });

  final StickerModel sticker;
  final String? emoji;

  factory StickerMessageInfo.fromTdlib(Map<String, dynamic> content) {
    final stickerRaw = content['sticker'] as Map<String, dynamic>? ?? {};
    return StickerMessageInfo(
      sticker: StickerModel.fromTdlib(stickerRaw),
      emoji: stickerRaw['emoji'] as String?,
    );
  }
}

class AnimationMessageInfo {
  const AnimationMessageInfo({
    required this.animation,
    this.caption,
  });

  final AnimationModel animation;
  final String? caption;

  factory AnimationMessageInfo.fromTdlib(Map<String, dynamic> content) {
    final animationRaw = content['animation'] as Map<String, dynamic>? ?? {};
    final captionFormatted = content['caption'] as Map<String, dynamic>?;
    return AnimationMessageInfo(
      animation: AnimationModel.fromTdlib(animationRaw),
      caption: captionFormatted?['text'] as String?,
    );
  }
}

/// Парсинг ссылок на стикерпаки t.me/addstickers/Name
class StickerLinkParser {
  const StickerLinkParser._();

  static String? parseSetName(String link) {
    final trimmed = link.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return _matchName(trimmed);
    }
    if (uri.host.contains('t.me') || uri.host.contains('telegram.me')) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) {
        return null;
      }
      if (segments.first == 'addstickers' && segments.length >= 2) {
        return segments[1];
      }
      return segments.last;
    }
    return _matchName(trimmed);
  }

  static String? _matchName(String value) {
    final match = RegExp(r'addstickers/([A-Za-z0-9_]+)').firstMatch(value);
    return match?.group(1);
  }
}

extension MessageKindStickerX on MessageKind {
  bool get isStickerOrAnimation =>
      this == MessageKind.sticker || this == MessageKind.animation;
}
