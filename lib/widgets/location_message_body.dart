import 'package:flutter/material.dart';

import '../models/location_models.dart';

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
    final accent = isExpired
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.primary;

    return InkWell(
      onTap: onOpenMap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
        ),
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
            const SizedBox(height: 8),
            Text(
              point.coordinatesLabel,
              style: theme.textTheme.bodySmall,
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
            if (onOpenMap != null) ...[
              const SizedBox(height: 8),
              Text(
                'Открыть на карте',
                style: theme.textTheme.labelMedium?.copyWith(color: accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
