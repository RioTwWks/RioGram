import 'package:flutter/material.dart';

import '../core/theme/telegram_theme.dart';
import '../models/location_models.dart';
import 'static_map_preview.dart';

/// Карточка геолокации / venue в пузыре сообщения.
class LocationMessageBody extends StatelessWidget {
  const LocationMessageBody({
    super.key,
    required this.preview,
    required this.point,
    this.subtitle,
    this.isLive = false,
    this.isExpired = false,
    this.isBroadcasting = false,
    this.onOpenMap,
  });

  final String preview;
  final LocationPoint point;
  final String? subtitle;
  final bool isLive;
  final bool isExpired;
  final bool isBroadcasting;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tg = context.telegramTheme;
    final accent = isExpired ? tg.textSecondary : tg.accent;

    return InkWell(
      onTap: onOpenMap,
      borderRadius: BorderRadius.circular(TelegramRadii.mediaPreview),
      child: Container(
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
        decoration: BoxDecoration(
          color: tg.elevatedSurface.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(TelegramRadii.mediaPreview),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaticMapPreview(point: point),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isLive ? Icons.my_location : Icons.location_on_outlined,
                        size: 20,
                        color: accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          preview,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    point.coordinatesLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tg.textSecondary,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tg.textSecondary,
                      ),
                    ),
                  ],
                  if (isLive && isBroadcasting) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Трансляция активна',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
