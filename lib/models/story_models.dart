import '../core/tdlib/tdlib_json.dart';

/// Состояние просмотра историй у постера.
enum StoryReadState {
  none,
  unread,
  read,
  live,
}

/// Краткая информация об одной истории в ленте.
class StoryInfoSummary {
  const StoryInfoSummary({
    required this.storyId,
    required this.date,
    this.isForCloseFriends = false,
    this.isLive = false,
  });

  final int storyId;
  final DateTime date;
  final bool isForCloseFriends;
  final bool isLive;

  factory StoryInfoSummary.fromTdlib(Map<String, dynamic> json) {
    return StoryInfoSummary(
      storyId: tdIntOr(json['story_id']),
      date: DateTime.fromMillisecondsSinceEpoch(tdIntOr(json['date']) * 1000),
      isForCloseFriends: json['is_for_close_friends'] as bool? ?? false,
      isLive: json['is_live'] as bool? ?? false,
    );
  }
}

/// Активные истории одного чата/контакта.
class StoryPosterSummary {
  const StoryPosterSummary({
    required this.chatId,
    required this.stories,
    this.maxReadStoryId = 0,
    this.order = 0,
    this.canBeArchived = false,
    this.title = '',
    this.avatarLocalPath,
  });

  final int chatId;
  final List<StoryInfoSummary> stories;
  final int maxReadStoryId;
  final int order;
  final bool canBeArchived;
  final String title;
  final String? avatarLocalPath;

  bool get hasStories => stories.isNotEmpty;

  bool get hasUnread {
    if (stories.isEmpty) {
      return false;
    }
    return stories.any((story) => story.storyId > maxReadStoryId);
  }

  StoryReadState get readState {
    if (stories.any((story) => story.isLive)) {
      return StoryReadState.live;
    }
    if (hasUnread) {
      return StoryReadState.unread;
    }
    if (hasStories) {
      return StoryReadState.read;
    }
    return StoryReadState.none;
  }

  StoryPosterSummary copyWith({
    List<StoryInfoSummary>? stories,
    int? maxReadStoryId,
    int? order,
    bool? canBeArchived,
    String? title,
    String? avatarLocalPath,
  }) {
    return StoryPosterSummary(
      chatId: chatId,
      stories: stories ?? this.stories,
      maxReadStoryId: maxReadStoryId ?? this.maxReadStoryId,
      order: order ?? this.order,
      canBeArchived: canBeArchived ?? this.canBeArchived,
      title: title ?? this.title,
      avatarLocalPath: avatarLocalPath ?? this.avatarLocalPath,
    );
  }
}

/// Тип медиа истории.
enum StoryMediaKind {
  photo,
  video,
  live,
  unsupported,
}

/// Полная история с медиа и метаданными.
class StoryModel {
  const StoryModel({
    required this.id,
    required this.posterChatId,
    required this.date,
    this.mediaKind = StoryMediaKind.unsupported,
    this.mediaFileId,
    this.mediaLocalPath,
    this.caption = '',
    this.canBeReplied = false,
    this.canBeForwarded = false,
    this.chosenReactionEmoji,
    this.viewCount = 0,
    this.isLive = false,
  });

  final int id;
  final int posterChatId;
  final DateTime date;
  final StoryMediaKind mediaKind;
  final int? mediaFileId;
  final String? mediaLocalPath;
  final String caption;
  final bool canBeReplied;
  final bool canBeForwarded;
  final String? chosenReactionEmoji;
  final int viewCount;
  final bool isLive;

  String get cacheKey => '${posterChatId}_$id';

  StoryModel copyWith({
    StoryMediaKind? mediaKind,
    int? mediaFileId,
    String? mediaLocalPath,
    String? caption,
    bool? canBeReplied,
    bool? canBeForwarded,
    String? chosenReactionEmoji,
    int? viewCount,
    bool? isLive,
  }) {
    return StoryModel(
      id: id,
      posterChatId: posterChatId,
      date: date,
      mediaKind: mediaKind ?? this.mediaKind,
      mediaFileId: mediaFileId ?? this.mediaFileId,
      mediaLocalPath: mediaLocalPath ?? this.mediaLocalPath,
      caption: caption ?? this.caption,
      canBeReplied: canBeReplied ?? this.canBeReplied,
      canBeForwarded: canBeForwarded ?? this.canBeForwarded,
      chosenReactionEmoji: chosenReactionEmoji ?? this.chosenReactionEmoji,
      viewCount: viewCount ?? this.viewCount,
      isLive: isLive ?? this.isLive,
    );
  }
}

/// Состояние публикации истории.
class StoryPostState {
  const StoryPostState({
    this.isPosting = false,
    this.canPost = false,
    this.lastError,
  });

  final bool isPosting;
  final bool canPost;
  final String? lastError;

  StoryPostState copyWith({
    bool? isPosting,
    bool? canPost,
    String? lastError,
  }) {
    return StoryPostState(
      isPosting: isPosting ?? this.isPosting,
      canPost: canPost ?? this.canPost,
      lastError: lastError,
    );
  }
}

/// Реакция для истории.
class StoryReactionOption {
  const StoryReactionOption({required this.emoji});

  final String emoji;

  Map<String, dynamic> toReactionType() => {
        '@type': 'reactionTypeEmoji',
        'emoji': emoji,
      };
}
