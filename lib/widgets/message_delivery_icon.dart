import 'package:flutter/material.dart';

import '../core/theme/telegram_icons.dart';
import '../models/message_enrichment.dart';

/// Иконки статуса доставки исходящего сообщения (как в Telegram).
///
/// - [MessageDeliveryStatus.sent] — одна серая галочка
/// - [MessageDeliveryStatus.delivered] — две серые галочки
/// - [MessageDeliveryStatus.read] — две синие галочки
class MessageDeliveryIcon extends StatelessWidget {
  const MessageDeliveryIcon({
    super.key,
    required this.status,
    this.size = 14,
    this.defaultColor,
    this.readColor,
  });

  final MessageDeliveryStatus status;
  final double size;
  final Color? defaultColor;
  final Color? readColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = defaultColor ?? theme.colorScheme.onSurfaceVariant;
    final read = readColor ?? theme.colorScheme.primary;

    return switch (status) {
      MessageDeliveryStatus.sending => Icon(
          TelegramIcons.deliverySending,
          size: size,
          color: color,
        ),
      MessageDeliveryStatus.failed => Icon(
          TelegramIcons.deliveryFailed,
          size: size,
          color: theme.colorScheme.error,
        ),
      MessageDeliveryStatus.sent => Icon(
          TelegramIcons.deliverySent,
          size: size,
          color: color,
        ),
      MessageDeliveryStatus.delivered => Icon(
          TelegramIcons.deliveryDelivered,
          size: size,
          color: color,
        ),
      MessageDeliveryStatus.read => Icon(
          TelegramIcons.deliveryDelivered,
          size: size,
          color: read,
        ),
    };
  }
}

/// Счётчик просмотров для каналов.
class MessageViewCountLabel extends StatelessWidget {
  const MessageViewCountLabel({
    super.key,
    required this.viewCount,
  });

  final int viewCount;

  @override
  Widget build(BuildContext context) {
    if (viewCount <= 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          TelegramIcons.visibility,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          _formatCount(viewCount),
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }

  static String _formatCount(int value) {
    if (value >= 1_000_000) {
      return '${(value / 1_000_000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }
}
