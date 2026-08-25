import 'package:flutter/material.dart';

import '../models/message_enrichment.dart';

/// Иконки статуса доставки исходящего сообщения.
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
      MessageDeliveryStatus.sending =>
        Icon(Icons.access_time, size: size, color: color),
      MessageDeliveryStatus.failed =>
        Icon(Icons.error_outline, size: size, color: theme.colorScheme.error),
      MessageDeliveryStatus.sent => Icon(Icons.check, size: size, color: color),
      MessageDeliveryStatus.read =>
        Icon(Icons.done_all, size: size, color: read),
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
        Icon(Icons.visibility_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
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
