import '../../models/story_models.dart';
import '../tdlib/tdlib_json.dart';

/// Парсинг TDLib story / chatActiveStories.
class TdlibStoryParser {
  const TdlibStoryParser._();

  static StoryPosterSummary? parseChatActiveStories(Map<String, dynamic>? json) {
    if (json == null || json['@type'] != 'chatActiveStories') {
      return null;
    }

    final chatId = tdIntOr(json['chat_id']);
    if (chatId == 0) {
      return null;
    }

    final rawStories = json['stories'] as List<dynamic>? ?? const [];
    final stories = rawStories
        .whereType<Map<String, dynamic>>()
        .map(StoryInfoSummary.fromTdlib)
        .toList();

    return StoryPosterSummary(
      chatId: chatId,
      stories: stories,
      maxReadStoryId: tdIntOr(json['max_read_story_id']),
      order: tdIntOr(json['order']),
      canBeArchived: json['can_be_archived'] as bool? ?? false,
    );
  }

  static StoryModel? parseStory(Map<String, dynamic>? json) {
    if (json == null || json['@type'] != 'story') {
      return null;
    }

    final id = tdIntOr(json['id']);
    final posterChatId = tdIntOr(json['poster_chat_id']);
    if (id == 0 || posterChatId == 0) {
      return null;
    }

    final content = json['content'] as Map<String, dynamic>? ?? {};
    final media = _parseStoryMedia(content);
    final captionJson = json['caption'] as Map<String, dynamic>?;
    final interaction = json['interaction_info'] as Map<String, dynamic>?;
    final reaction = json['chosen_reaction_type'] as Map<String, dynamic>?;

    return StoryModel(
      id: id,
      posterChatId: posterChatId,
      date: DateTime.fromMillisecondsSinceEpoch(tdIntOr(json['date']) * 1000),
      mediaKind: media.kind,
      mediaFileId: media.fileId,
      mediaLocalPath: media.localPath,
      caption: captionJson?['text'] as String? ?? '',
      canBeReplied: json['can_be_replied'] as bool? ?? false,
      canBeForwarded: json['can_be_forwarded'] as bool? ?? false,
      chosenReactionEmoji: _parseReactionEmoji(reaction),
      viewCount: tdIntOr(interaction?['view_count']),
      isLive: media.kind == StoryMediaKind.live,
    );
  }

  static List<StoryReactionOption> parseAvailableReactions(
    Map<String, dynamic>? json,
  ) {
    if (json == null || json['@type'] != 'availableReactions') {
      return _defaultReactions;
    }

    final top = json['top_reactions'] as List<dynamic>? ?? const [];
    final recent = json['recent_reactions'] as List<dynamic>? ?? const [];
    final popular = json['popular_reactions'] as List<dynamic>? ?? const [];

    final emojis = <String>{};
    for (final bucket in [top, recent, popular]) {
      for (final item in bucket) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final type = item['type'] as Map<String, dynamic>?;
        final emoji = _parseReactionEmoji(type);
        if (emoji != null && emoji.isNotEmpty) {
          emojis.add(emoji);
        }
      }
    }

    if (emojis.isEmpty) {
      return _defaultReactions;
    }

    return emojis
        .map((emoji) => StoryReactionOption(emoji: emoji))
        .toList(growable: false);
  }

  static const List<StoryReactionOption> _defaultReactions = [
    StoryReactionOption(emoji: '❤️'),
    StoryReactionOption(emoji: '🔥'),
    StoryReactionOption(emoji: '👏'),
    StoryReactionOption(emoji: '😂'),
    StoryReactionOption(emoji: '😮'),
  ];

  static ({StoryMediaKind kind, int? fileId, String? localPath}) _parseStoryMedia(
    Map<String, dynamic> content,
  ) {
    return switch (content['@type']) {
      'storyContentPhoto' => _parsePhoto(content['photo'] as Map<String, dynamic>?),
      'storyContentVideo' => _parseVideo(content['video'] as Map<String, dynamic>?),
      'storyContentLive' => (
          kind: StoryMediaKind.live,
          fileId: null,
          localPath: null,
        ),
      _ => (kind: StoryMediaKind.unsupported, fileId: null, localPath: null),
    };
  }

  static ({StoryMediaKind kind, int? fileId, String? localPath}) _parsePhoto(
    Map<String, dynamic>? photo,
  ) {
    if (photo == null) {
      return (kind: StoryMediaKind.photo, fileId: null, localPath: null);
    }
    final sizes = photo['sizes'] as List<dynamic>? ?? const [];
    Map<String, dynamic>? best;
    var bestArea = 0;
    for (final size in sizes) {
      if (size is! Map<String, dynamic>) {
        continue;
      }
      final width = tdIntOr(size['width']);
      final height = tdIntOr(size['height']);
      final area = width * height;
      if (area >= bestArea) {
        bestArea = area;
        best = size;
      }
    }
    final photoData = best?['photo'] as Map<String, dynamic>?;
    final file = photoData?['file'] as Map<String, dynamic>? ??
        (photoData?['@type'] == 'file' ? photoData : null) ??
        photo['photo'] as Map<String, dynamic>?;
    return (
      kind: StoryMediaKind.photo,
      fileId: _fileIdFromFile(file),
      localPath: _localPathFromFile(file),
    );
  }

  static ({StoryMediaKind kind, int? fileId, String? localPath}) _parseVideo(
    Map<String, dynamic>? video,
  ) {
    if (video == null) {
      return (kind: StoryMediaKind.video, fileId: null, localPath: null);
    }
    final file = video['video'] as Map<String, dynamic>?;
    return (
      kind: StoryMediaKind.video,
      fileId: _fileIdFromFile(file),
      localPath: _localPathFromFile(file),
    );
  }

  static int? _fileIdFromFile(Map<String, dynamic>? file) {
    if (file == null) {
      return null;
    }
    return tdInt(file['id']);
  }

  static String? _localPathFromFile(Map<String, dynamic>? file) {
    if (file == null) {
      return null;
    }
    final local = file['local'] as Map<String, dynamic>?;
    final path = local?['path'] as String?;
    if (path == null || path.isEmpty) {
      return null;
    }
    if (local?['is_downloading_completed'] as bool? ?? false) {
      return path;
    }
    return null;
  }

  static String? _parseReactionEmoji(Map<String, dynamic>? reaction) {
    if (reaction == null) {
      return null;
    }
    if (reaction['@type'] == 'reactionTypeEmoji') {
      return reaction['emoji'] as String?;
    }
    return null;
  }
}
