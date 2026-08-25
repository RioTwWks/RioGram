import 'package:flutter/material.dart';

import '../core/theme/telegram_theme.dart';

/// Бейдж длительности видео в углу превью (§9.11.7).
class VideoDurationBadge extends StatelessWidget {
  const VideoDurationBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TelegramMediaSpacing.videoDurationBadgePaddingH,
          vertical: TelegramMediaSpacing.videoDurationBadgePaddingV,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: TelegramFontSizes.bubbleMeta,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
