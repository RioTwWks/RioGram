/// Контекст комментариев к посту канала (связанная группа-обсуждение).
class MessageThreadContext {
  const MessageThreadContext({
    required this.channelChatId,
    required this.channelMessageId,
    required this.discussionChatId,
    required this.messageThreadId,
    this.postPreview,
  });

  final int channelChatId;
  final int channelMessageId;
  final int discussionChatId;
  final int messageThreadId;
  final String? postPreview;
}

/// Состояние подписки на канал.
enum ChannelMembershipKind {
  unknown,
  subscribed,
  notSubscribed,
}

extension ChannelMembershipKindX on ChannelMembershipKind {
  bool get isSubscribed =>
      this == ChannelMembershipKind.subscribed || this == ChannelMembershipKind.unknown;
}
