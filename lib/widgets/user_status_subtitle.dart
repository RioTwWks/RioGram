import 'package:flutter/material.dart';

import '../models/user_models.dart';
import '../core/user/user_status_formatter.dart';

/// Подзаголовок со статусом пользователя.
class UserStatusSubtitle extends StatelessWidget {
  const UserStatusSubtitle({
    super.key,
    required this.status,
    this.style,
  });

  final UserStatusInfo status;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = UserStatusFormatter.format(status);
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final color = status.isOnline
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Text(
      text,
      style: (style ?? Theme.of(context).textTheme.bodySmall)?.copyWith(
        color: color,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
