import 'package:flutter/material.dart';

import '../core/theme/telegram_icons.dart';
import '../models/chat_models.dart';
import '../models/ui_customization_models.dart';

/// Обёртка свайп-жестов для сообщения (§7.3).
class MessageSwipeWrapper extends StatelessWidget {
  const MessageSwipeWrapper({
    super.key,
    required this.message,
    required this.endToStartAction,
    required this.startToEndAction,
    required this.child,
    this.onReply,
    this.onForward,
    this.onDelete,
  });

  final ChatMessage message;
  final MessageSwipeAction endToStartAction;
  final MessageSwipeAction startToEndAction;
  final Widget child;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final directions = <DismissDirection>[];
    if (endToStartAction != MessageSwipeAction.none) {
      directions.add(DismissDirection.endToStart);
    }
    if (startToEndAction != MessageSwipeAction.none) {
      directions.add(DismissDirection.startToEnd);
    }
    if (directions.isEmpty) {
      return child;
    }

    return Dismissible(
      key: ValueKey('msg_swipe_${message.chatId}_${message.id}'),
      direction: directions.length == 1
          ? directions.first
          : DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        final action = direction == DismissDirection.endToStart
            ? endToStartAction
            : startToEndAction;
        _runAction(action);
        return false;
      },
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        action: startToEndAction,
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        action: endToStartAction,
      ),
      child: child,
    );
  }

  void _runAction(MessageSwipeAction action) {
    switch (action) {
      case MessageSwipeAction.none:
        break;
      case MessageSwipeAction.reply:
        onReply?.call();
      case MessageSwipeAction.forward:
        onForward?.call();
      case MessageSwipeAction.delete:
        onDelete?.call();
    }
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.action,
  });

  final Alignment alignment;
  final MessageSwipeAction action;

  @override
  Widget build(BuildContext context) {
    if (action == MessageSwipeAction.none) {
      return const SizedBox.shrink();
    }

    final (icon, label, color) = switch (action) {
      MessageSwipeAction.reply => (
          TelegramIcons.reply,
          'Ответить',
          Colors.blue,
        ),
      MessageSwipeAction.forward => (
          TelegramIcons.forward,
          'Переслать',
          Colors.teal,
        ),
      MessageSwipeAction.delete => (
          TelegramIcons.delete,
          'Удалить',
          Colors.red,
        ),
      MessageSwipeAction.none => (Icons.block, '', Colors.grey),
    };

    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: color.withValues(alpha: 0.85),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerRight) ...[
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(icon, color: Colors.white),
          if (alignment == Alignment.centerLeft) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
