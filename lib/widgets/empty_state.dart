import 'package:flutter/material.dart';

import '../core/theme/telegram_theme.dart';

/// Пустое состояние: outline-иллюстрация + короткий текст (стиль Telegram).
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  static const double illustrationSize = 96;
  static const double iconSize = 56;

  @override
  Widget build(BuildContext context) {
    final telegram = context.telegramTheme;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: illustrationSize,
              height: illustrationSize,
              decoration: BoxDecoration(
                color: telegram.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: telegram.accent.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: telegram.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: telegram.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
