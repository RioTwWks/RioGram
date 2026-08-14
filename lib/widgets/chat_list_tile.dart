import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  });

  final ChatSummary chat;
  final bool selected;
  final ChatListKey activeList;
  final VoidCallback onTap;
  final VoidCallback? onPinToggle;
  final VoidCallback? onArchiveToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPinned = chat.isPinnedIn(activeList);
    final preview = chat.previewText;
    final hasDraft = chat.draftPreview != null && chat.draftPreview!.isNotEmpty;
    final time = chat.lastMessageDate != null
        ? formatChatListTime(chat.lastMessageDate!)
        : null;

    final previewStyle = theme.textTheme.bodyMedium?.copyWith(
      color: hasDraft
          ? theme.colorScheme.error
          : chat.isMuted
              ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
              : theme.colorScheme.onSurface.withValues(alpha: 0.65),
    );

    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showActions(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChatAvatar(
                title: chat.title,
                localPath: chat.avatarLocalPath,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          chatKindIcon(chat.kind),
                          size: 16,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            chat.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isPinned) ...[
                          Icon(
                            Icons.push_pin,
                            size: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (chat.isMuted) ...[
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (time != null)
                          Text(
                            time,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                      ],
                    ),
                    if (preview != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: previewStyle,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (chat.unreadCount > 0)
                _UnreadBadge(count: chat.unreadCount, muted: chat.isMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    final isPinned = chat.isPinnedIn(activeList);
    final isArchive = activeList is ChatListArchive;

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
                leading: Icon(isArchive ? Icons.unarchive_outlined : Icons.archive_outlined),
                title: Text(isArchive ? 'Из архива' : 'В архив'),
                onTap: () {
                  Navigator.pop(context);
                  onArchiveToggle?.call();
                },
              ),
            ],
          ),
        );
      },
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
    final label = count > 99 ? '99+' : '$count';
    final color = muted
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35)
        : const Color(0xFF3390EC);

    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
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
            onSelected: (_) => onSelected(tab.list),
          );
        },
      ),
    );
  }
}
