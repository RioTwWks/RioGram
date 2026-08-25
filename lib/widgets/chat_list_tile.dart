import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/telegram_theme.dart';
import '../models/chat_models.dart';
import 'chat_avatar.dart';

/// Иконка типа чата в списке.
IconData chatKindIcon(ChatKind kind) {
  return switch (kind) {
    ChatKind.privateChat => Icons.person_outline,
    ChatKind.group => Icons.group_outlined,
    ChatKind.channel => Icons.campaign_outlined,
    ChatKind.bot => Icons.smart_toy_outlined,
    ChatKind.secret => Icons.lock_outline,
    ChatKind.savedMessages => Icons.bookmark_outline,
  };
}

/// Форматирование времени последнего сообщения как в Telegram.
String formatChatListTime(DateTime dateTime) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

  if (messageDay == today) {
    return DateFormat('HH:mm').format(dateTime);
  }

  final yesterday = today.subtract(const Duration(days: 1));
  if (messageDay == yesterday) {
    return 'вчера';
  }

  if (now.difference(dateTime).inDays < 7) {
    const weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    return weekdays[dateTime.weekday - 1];
  }

  return DateFormat('dd.MM.yy').format(dateTime);
}

/// Разбор preview: иконка статуса + текст без emoji-префикса.
@visibleForTesting
({IconData? icon, String text, bool isDraft}) parseChatPreviewParts(
  String? previewText, {
  required bool hasDraft,
}) {
  if (previewText == null || previewText.isEmpty) {
    return (icon: null, text: '', isDraft: false);
  }

  if (hasDraft) {
    final text = previewText.startsWith('Черновик: ')
        ? previewText.substring('Черновик: '.length)
        : previewText;
    return (icon: Icons.edit_outlined, text: text, isDraft: true);
  }

  const mediaPrefixes = <String, IconData>{
    '📷 ': Icons.photo_camera_outlined,
    '🎤 ': Icons.mic,
    '🎬 ': Icons.videocam_outlined,
    '⭕ ': Icons.videocam_outlined,
    '📎 ': Icons.attach_file,
    '🎵 ': Icons.music_note_outlined,
    '🎞 ': Icons.gif_box_outlined,
    '📊 ': Icons.poll_outlined,
  };

  for (final entry in mediaPrefixes.entries) {
    if (previewText.startsWith(entry.key)) {
      return (
        icon: entry.value,
        text: previewText.substring(entry.key.length),
        isDraft: false,
      );
    }
  }

  return (icon: null, text: previewText, isDraft: false);
}

/// Строка чата в списке с иконками типа, mute, pin и badge непрочитанных.
class ChatListTile extends StatelessWidget {
  const ChatListTile({
    super.key,
    required this.chat,
    required this.selected,
    required this.activeList,
    required this.onTap,
    this.onPinToggle,
    this.onArchiveToggle,
    this.onToggleUnread,
    this.onClearHistory,
    this.onDeleteChat,
    this.onDeleteForAll,
    this.showDivider = false,
  });

  final ChatSummary chat;
  final bool selected;
  final ChatListKey activeList;
  final VoidCallback onTap;
  final VoidCallback? onPinToggle;
  final VoidCallback? onArchiveToggle;
  final VoidCallback? onToggleUnread;
  final VoidCallback? onClearHistory;
  final VoidCallback? onDeleteChat;
  final VoidCallback? onDeleteForAll;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tg = context.telegramTheme;
    final isPinned = chat.isPinnedIn(activeList);
    final preview = chat.previewText;
    final hasDraft = chat.draftPreview != null && chat.draftPreview!.isNotEmpty;
    final previewParts = parseChatPreviewParts(preview, hasDraft: hasDraft);
    final time = chat.lastMessageDate != null
        ? formatChatListTime(chat.lastMessageDate!)
        : null;

    final previewOpacity = chat.isMuted ? 0.45 : 1.0;
    final previewStyle = theme.textTheme.bodyMedium?.copyWith(
      color: hasDraft
          ? theme.colorScheme.error.withValues(alpha: previewOpacity)
          : tg.textSecondary.withValues(alpha: previewOpacity),
      fontWeight: chat.showsUnreadIndicator ? FontWeight.w600 : FontWeight.normal,
    );

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: tg.textPrimary,
    );

    final timeStyle = theme.textTheme.labelSmall?.copyWith(
      color: chat.showsUnreadIndicator ? tg.accent : tg.textTime,
      fontWeight: chat.showsUnreadIndicator ? FontWeight.w600 : FontWeight.w400,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: selected ? tg.accent.withValues(alpha: 0.08) : tg.chatListBackground,
          child: InkWell(
            onTap: onTap,
            onLongPress: () => _showActions(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChatAvatar(
                    title: chat.title,
                    localPath: chat.avatarLocalPath,
                    radius: TelegramRadii.avatarList,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                chat.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle,
                              ),
                            ),
                            if (isPinned) ...[
                              Icon(
                                Icons.push_pin,
                                size: 14,
                                color: tg.textSecondary,
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (chat.isMuted) ...[
                              _MutedBellIcon(color: tg.textSecondary),
                              const SizedBox(width: 4),
                            ],
                          ],
                        ),
                        if (previewParts.text.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (previewParts.icon != null) ...[
                                Icon(
                                  previewParts.icon,
                                  size: 16,
                                  color: previewStyle?.color,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  previewParts.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: previewStyle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 52,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (time != null)
                          Text(
                            time,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: timeStyle,
                          ),
                        const SizedBox(height: 6),
                        _UnreadIndicator(chat: chat),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: TelegramSpacing.chatListDividerInset,
            color: tg.chatListDivider,
          ),
      ],
    );
  }

  void _showActions(BuildContext context) {
    final isPinned = chat.isPinnedIn(activeList);
    final isArchive = activeList is ChatListArchive;
    final markUnreadLabel = chat.isMarkedAsUnread
        ? 'Отметить прочитанным'
        : 'Отметить непрочитанным';

    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin),
                title: Text(isPinned ? 'Открепить' : 'Закрепить'),
                onTap: () {
                  Navigator.pop(context);
                  onPinToggle?.call();
                },
              ),
              ListTile(
                leading: const Icon(Icons.mark_chat_unread_outlined),
                title: Text(markUnreadLabel),
                onTap: () {
                  Navigator.pop(context);
                  onToggleUnread?.call();
                },
              ),
              ListTile(
                leading: Icon(isArchive ? Icons.unarchive_outlined : Icons.archive_outlined),
                title: Text(isArchive ? 'Из архива' : 'В архив'),
                onTap: () {
                  Navigator.pop(context);
                  onArchiveToggle?.call();
                },
              ),
              if (chat.canBeDeletedOnlyForSelf && onClearHistory != null)
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: const Text('Очистить историю'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirm(
                      context,
                      title: 'Очистить историю?',
                      message: 'Сообщения будут удалены только у вас.',
                      onConfirm: onClearHistory!,
                    );
                  },
                ),
              if (onDeleteChat != null)
                ListTile(
                  leading: Icon(
                    chat.canLeave ? Icons.logout : Icons.delete_outline,
                  ),
                  title: Text(chat.canLeave ? 'Покинуть чат' : 'Удалить чат'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirm(
                      context,
                      title: chat.canLeave ? 'Покинуть чат?' : 'Удалить чат?',
                      message: chat.canLeave
                          ? 'Вы больше не будете получать сообщения из этого чата.'
                          : 'Чат будет удалён из списка.',
                      onConfirm: onDeleteChat!,
                    );
                  },
                ),
              if (chat.canBeDeletedForAllUsers && onDeleteForAll != null)
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                  title: const Text(
                    'Удалить для всех',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirm(
                      context,
                      title: 'Удалить для всех?',
                      message: 'История будет удалена у всех участников.',
                      destructive: true,
                      onConfirm: onDeleteForAll!,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
    bool destructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onConfirm();
    }
  }
}

class _MutedBellIcon extends StatelessWidget {
  const _MutedBellIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 14, color: color),
          Transform.rotate(
            angle: -0.7,
            child: Container(
              width: 16,
              height: 1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadIndicator extends StatelessWidget {
  const _UnreadIndicator({required this.chat});

  final ChatSummary chat;

  @override
  Widget build(BuildContext context) {
    if (chat.unreadCount > 0) {
      return _UnreadBadge(count: chat.unreadCount, muted: chat.isMuted);
    }
    if (chat.isMarkedAsUnread) {
      final tg = context.telegramTheme;
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: tg.unreadBadgeBackground,
          shape: BoxShape.circle,
        ),
      );
    }
    return const SizedBox(
      width: TelegramSpacing.unreadBadgeMinWidth,
      height: TelegramSpacing.unreadBadgeMinHeight,
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({
    required this.count,
    required this.muted,
  });

  final int count;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    final label = count > 99 ? '99+' : '$count';
    final backgroundColor = muted
        ? tg.textSecondary.withValues(alpha: 0.35)
        : tg.unreadBadgeBackground;

    return Container(
      constraints: const BoxConstraints(
        minWidth: TelegramSpacing.unreadBadgeMinWidth,
        minHeight: TelegramSpacing.unreadBadgeMinHeight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(TelegramRadii.unreadBadge),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: tg.unreadBadgeText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Свайп-действие «В архив» / «Из архива».
class ChatListDismissible extends StatelessWidget {
  const ChatListDismissible({
    super.key,
    required this.chat,
    required this.activeList,
    required this.child,
    required this.onArchiveToggle,
  });

  final ChatSummary chat;
  final ChatListKey activeList;
  final Widget child;
  final VoidCallback onArchiveToggle;

  @override
  Widget build(BuildContext context) {
    final isArchive = activeList is ChatListArchive;
    final label = isArchive ? 'Из архива' : 'В архив';
    final icon = isArchive ? Icons.unarchive_outlined : Icons.archive_outlined;
    final color = isArchive ? Colors.green : Colors.orange;

    return Dismissible(
      key: ValueKey('chat_swipe_${chat.id}_${activeList.storageId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onArchiveToggle();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: color,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}

/// Горизонтальные вкладки: все чаты, папки, архив.
class ChatListTabs extends StatelessWidget {
  const ChatListTabs({
    super.key,
    required this.activeList,
    required this.folders,
    required this.onSelected,
  });

  final ChatListKey activeList;
  final List<ChatFolderTab> folders;
  final ValueChanged<ChatListKey> onSelected;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    final tabs = <({ChatListKey list, String label})>[
      (list: const ChatListMain(), label: 'Все'),
      ...folders.map((folder) => (list: folder.listKey, label: folder.name)),
      (list: const ChatListArchive(), label: 'Архив'),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final selected = tab.list.storageId == activeList.storageId;
          return ChoiceChip(
            label: Text(tab.label),
            selected: selected,
            selectedColor: tg.accent.withValues(alpha: 0.12),
            labelStyle: TextStyle(
              color: selected ? tg.accent : tg.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
            side: BorderSide.none,
            onSelected: (_) => onSelected(tab.list),
          );
        },
      ),
    );
  }
}
