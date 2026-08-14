import 'package:flutter/material.dart';

/// Баннер подписки на канал, когда пользователь не участник.
class ChannelSubscribeBanner extends StatelessWidget {
  const ChannelSubscribeBanner({
    super.key,
    required this.channelTitle,
    required this.onSubscribe,
    this.isLoading = false,
  });

  final String channelTitle;
  final VoidCallback onSubscribe;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.campaign_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Подпишитесь на «$channelTitle», чтобы видеть все посты',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            FilledButton(
              onPressed: isLoading ? null : onSubscribe,
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Подписаться'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only подсказка для подписчиков канала без права публикации.
class ChannelReadOnlyBar extends StatelessWidget {
  const ChannelReadOnlyBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 20,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Канал доступен только для чтения',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
