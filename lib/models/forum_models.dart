/// Краткая информация о теме форума для списка.
class ForumTopicSummary {
  const ForumTopicSummary({
    required this.forumTopicId,
    required this.name,
    this.isGeneral = false,
    this.isClosed = false,
    this.isPinned = false,
    this.unreadCount = 0,
    this.lastMessagePreview,
    this.lastMessageDate,
    this.order = 0,
  });

  final int forumTopicId;
  final String name;
  final bool isGeneral;
  final bool isClosed;
  final bool isPinned;
  final int unreadCount;
  final String? lastMessagePreview;
  final DateTime? lastMessageDate;
  final int order;

  String get displayName {
    if (isGeneral) {
      return 'General';
    }
    return name;
  }

  ForumTopicSummary copyWith({
    String? name,
    bool? isGeneral,
    bool? isClosed,
    bool? isPinned,
    int? unreadCount,
    String? lastMessagePreview,
    DateTime? lastMessageDate,
    int? order,
  }) {
    return ForumTopicSummary(
      forumTopicId: forumTopicId,
      name: name ?? this.name,
      isGeneral: isGeneral ?? this.isGeneral,
      isClosed: isClosed ?? this.isClosed,
      isPinned: isPinned ?? this.isPinned,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageDate: lastMessageDate ?? this.lastMessageDate,
      order: order ?? this.order,
    );
  }
}

/// Смещения для пагинации getForumTopics.
class ForumTopicsPageOffset {
  const ForumTopicsPageOffset({
    this.offsetDate = 0,
    this.offsetMessageId = 0,
    this.offsetForumTopicId = 0,
  });

  final int offsetDate;
  final int offsetMessageId;
  final int offsetForumTopicId;

  bool get isInitial =>
      offsetDate == 0 && offsetMessageId == 0 && offsetForumTopicId == 0;
}
