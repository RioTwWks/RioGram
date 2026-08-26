import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme/telegram_icons.dart';
import '../core/theme/telegram_theme.dart';
import '../core/theme/ui_customization_manager.dart';
import '../models/chat_models.dart';
import '../models/message_enrichment.dart';
import '../models/ui_customization_models.dart';
import 'chat_avatar.dart';
import 'message_delivery_icon.dart';

/// Иконка типа чата в списке.
IconData chatKindIcon(ChatKind kind) {
  return switch (kind) {
    ChatKind.privateChat => TelegramIcons.privateChat,
    ChatKind.group => TelegramIcons.group,
    ChatKind.channel => TelegramIcons.channel,
    ChatKind.bot => TelegramIcons.bot,
    ChatKind.secret => TelegramIcons.secretChat,
    ChatKind.savedMessages => TelegramIcons.savedMessages,
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

/// Разбор preview: иконка статуса + текст без emoji-префикса + галочки исходящих.
@visibleForTesting
({
  IconData? icon,
  String text,
  bool isDraft,
  MessageDeliveryStatus? outgoingStatus,
}) parseChatPreviewParts(
  String? previewText, {
  required bool hasDraft,
  bool isOutgoing = false,
  MessageDeliveryStatus? deliveryStatus,
}) {
  if (previewText == null || previewText.isEmpty) {
    return (icon: null, text: '', isDraft: false, outgoingStatus: null);
  }

  if (hasDraft) {
    final text = previewText.startsWith('Черновик: ')
        ? previewText.substring('Черновик: '.length)
        : previewText;
    return (icon: TelegramIcons.draft, text: text, isDraft: true, outgoingStatus: null);
  }

  const mediaPrefixes = <String, IconData>{
    '📷 ': TelegramIcons.photo,
    '🎤 ': TelegramIcons.mic,
    '🎬 ': TelegramIcons.video,
    '⭕ ': TelegramIcons.video,
    '📎 ': TelegramIcons.document,
    '🎵 ': TelegramIcons.music,
    '🎞 ': TelegramIcons.gif,
    '📊 ': TelegramIcons.poll,
  };

  for (final entry in mediaPrefixes.entries) {
    if (previewText.startsWith(entry.key)) {
      return (
        icon: entry.value,
        text: previewText.substring(entry.key.length),
        isDraft: false,
        outgoingStatus: isOutgoing ? deliveryStatus : null,
      );
    }
  }

  return (
    icon: null,
    text: previewText,
    isDraft: false,
    outgoingStatus: isOutgoing ? deliveryStatus : null,
  );
}

/// Префикс имени отправителя для групповых чатов (`Name: text`).
@visibleForTesting
String formatGroupChatPreviewText({
  required String text,
  String? senderName,
  required bool showPrefix,
}) {
  if (!showPrefix || senderName == null || senderName.isEmpty) {
    return text;
  }
  return '$senderName: $text';
}

/// Строка чата в списке с иконками типа, mute, pin и badge непрочитанных.
class ChatListTile extends StatelessWidget {
  const ChatListTile({
    super.key,
    required this.chat,
    required this.selected,
    required this.activeList,
    required this.onTap,
    this.chatActionPreview,
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
  final String? chatActionPreview;
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
    final showActionPreview =
        chatActionPreview != null && chatActionPreview!.isNotEmpty && !hasDraft;
    final previewParts = parseChatPreviewParts(
      preview,
      hasDraft: hasDraft,
      isOutgoing: chat.lastMessageIsOutgoing,
      deliveryStatus: chat.lastMessageDeliveryStatus,
    );
    final previewText = showActionPreview
        ? chatActionPreview!
        : formatGroupChatPreviewText(
            text: previewParts.text,
            senderName: chat.lastMessageSenderName,
            showPrefix: chat.showsGroupSenderPrefix &&
                !hasDraft &&
                !chat.lastMessageIsOutgoing,
          );
    final hasPreviewRow = showActionPreview || previewParts.text.isNotEmpty;
    final time = chat.lastMessageDate != null
        ? formatChatListTime(chat.lastMessageDate!)
        : null;

    final previewOpacity = chat.isMuted ? 0.45 : 1.0;
    final previewStyle = theme.textTheme.bodyMedium?.copyWith(
      color: showActionPreview
          ? tg.accent.withValues(alpha: previewOpacity)
          : hasDraft
              ? theme.colorScheme.error.withValues(alpha: previewOpacity)
              : tg.textSecondary.withValues(alpha: previewOpacity),
      fontWeight: chat.showsUnreadIndicator ? FontWeight.w600 : FontWeight.normal,
    );

    final showOutgoingStatus =
        previewParts.outgoingStatus != null && !hasDraft && !showActionPreview;

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: tg.textPrimary,
    );

    final timeStyle = theme.textTheme.labelSmall?.copyWith(
      color: chat.showsUnreadIndicator ? tg.accent : tg.textTime,
      fontWeight: chat.showsUnreadIndicator ? FontWeight.w600 : FontWeight.w400,
    );

    final ui = context.watch<UiCustomizationManager>();
    final showPinIcon = !ui.hideListIcons && isPinned;
    final showMuteIcon = !ui.hideMuteIcons && chat.isMuted;
    final showPreviewIcon = !ui.hideListIcons &&
        previewParts.icon != null &&
        !showActionPreview;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: selected
              ? tg.accent.withValues(alpha: 0.08)
              : tg.chatListBackground,
          child: InkWell(
            onTap: onTap,
            onLongPress: () => _showActions(context),
            hoverColor: tg.accent.withValues(alpha: 0.08),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TelegramSpacing.chatListRowHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
                              if (showPinIcon) ...[
                                Icon(
                                  TelegramIcons.pin,
                                  size: 14,
                                  color: tg.textSecondary,
                                ),
                                const SizedBox(width: 4),
                              ],
                              if (showMuteIcon) ...[
                                _MutedBellIcon(color: tg.textSecondary),
                                const SizedBox(width: 4),
                              ],
                              if (time != null)
                                Text(
                                  time,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: timeStyle,
                                ),
                            ],
                          ),
                          if (hasPreviewRow) ...[
                            const SizedBox(height: 3),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      if (showOutgoingStatus) ...[
                                        MessageDeliveryIcon(
                                          status: previewParts.outgoingStatus!,
                                          size: 16,
                                          defaultColor: previewStyle?.color,
                                          readColor: tg.accent,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      if (showPreviewIcon) ...[
                                        Icon(
                                          previewParts.icon,
                                          size: 16,
                                          color: previewStyle?.color,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: Text(
                                          previewText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: previewStyle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _UnreadIndicator(chat: chat),
                              ],
                            ),
                          ] else if (chat.showsUnreadIndicator) ...[
                            const SizedBox(height: 3),
                            Align(
                              alignment: Alignment.centerRight,
                              child: _UnreadIndicator(chat: chat),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
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
          Icon(TelegramIcons.mute, size: 14, color: color),
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

/// Свайп-действия в списке чатов (§7.3).
class ChatListDismissible extends StatelessWidget {
  const ChatListDismissible({
    super.key,
    required this.chat,
    required this.activeList,
    required this.child,
    required this.endToStartAction,
    required this.startToEndAction,
    this.onArchiveToggle,
    this.onMuteToggle,
    this.onDelete,
    this.onMarkRead,
    this.onPinToggle,
  });

  final ChatSummary chat;
  final ChatListKey activeList;
  final Widget child;
  final ChatSwipeAction endToStartAction;
  final ChatSwipeAction startToEndAction;
  final VoidCallback? onArchiveToggle;
  final VoidCallback? onMuteToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onMarkRead;
  final VoidCallback? onPinToggle;

  @override
  Widget build(BuildContext context) {
    final directions = <DismissDirection>[];
    if (endToStartAction != ChatSwipeAction.none) {
      directions.add(DismissDirection.endToStart);
    }
    if (startToEndAction != ChatSwipeAction.none) {
      directions.add(DismissDirection.startToEnd);
    }
    if (directions.isEmpty) {
      return child;
    }

    final isArchive = activeList is ChatListArchive;

    return Dismissible(
      key: ValueKey('chat_swipe_${chat.id}_${activeList.storageId}'),
      direction: directions.length == 1
          ? directions.first
          : DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        final action = direction == DismissDirection.endToStart
            ? endToStartAction
            : startToEndAction;
        _runAction(action, isArchive: isArchive);
        return false;
      },
      background: _ChatSwipeBackground(
        alignment: Alignment.centerLeft,
        action: startToEndAction,
        isArchive: isArchive,
      ),
      secondaryBackground: _ChatSwipeBackground(
        alignment: Alignment.centerRight,
        action: endToStartAction,
        isArchive: isArchive,
      ),
      child: child,
    );
  }

  void _runAction(ChatSwipeAction action, {required bool isArchive}) {
    switch (action) {
      case ChatSwipeAction.none:
        break;
      case ChatSwipeAction.archive:
        onArchiveToggle?.call();
      case ChatSwipeAction.mute:
        onMuteToggle?.call();
      case ChatSwipeAction.delete:
        onDelete?.call();
      case ChatSwipeAction.markRead:
        onMarkRead?.call();
      case ChatSwipeAction.pin:
        onPinToggle?.call();
    }
  }
}

class _ChatSwipeBackground extends StatelessWidget {
  const _ChatSwipeBackground({
    required this.alignment,
    required this.action,
    required this.isArchive,
  });

  final Alignment alignment;
  final ChatSwipeAction action;
  final bool isArchive;

  @override
  Widget build(BuildContext context) {
    if (action == ChatSwipeAction.none) {
      return const SizedBox.shrink();
    }

    final (icon, label, color) = switch (action) {
      ChatSwipeAction.archive => (
          isArchive ? Icons.unarchive_outlined : Icons.archive_outlined,
          isArchive ? 'Из архива' : 'В архив',
          isArchive ? Colors.green : Colors.orange,
        ),
      ChatSwipeAction.mute => (
          Icons.notifications_off_outlined,
          'Без звука',
          Colors.blueGrey,
        ),
      ChatSwipeAction.delete => (
          Icons.delete_outline,
          'Удалить',
          Colors.red,
        ),
      ChatSwipeAction.markRead => (
          Icons.done_all,
          'Прочитано',
          Colors.blue,
        ),
      ChatSwipeAction.pin => (
          Icons.push_pin,
          'Закрепить',
          Colors.purple,
        ),
      ChatSwipeAction.none => (Icons.block, '', Colors.grey),
    };

    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: color,
      child: Row(
        mainAxisAlignment: alignment == Alignment.centerRight
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Плоская вкладка с подчёркиванием в стиле Telegram.
class TelegramUnderlineTab extends StatelessWidget {
  const TelegramUnderlineTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? tg.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? tg.accent : tg.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: TelegramFontSizes.preview,
          ),
        ),
      ),
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

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: tg.chatListDivider, width: 1),
        ),
      ),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: tabs.length,
          separatorBuilder: (_, _) => const SizedBox(width: 0),
          itemBuilder: (context, index) {
            final tab = tabs[index];
            final selected = tab.list.storageId == activeList.storageId;
            return TelegramUnderlineTab(
              label: tab.label,
              selected: selected,
              onTap: () => onSelected(tab.list),
            );
          },
        ),
      ),
    );
  }
}
