import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/theme/telegram_theme.dart';
import '../models/link_preview_models.dart';

/// Карточка превью ссылки внутри пузыря (как в Telegram).
class LinkPreviewWidget extends StatelessWidget {
  const LinkPreviewWidget({
    super.key,
    required this.preview,
    this.accent,
    this.textSecondary,
  });

  final LinkPreviewInfo preview;
  final Color? accent;
  final Color? textSecondary;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    final accentColor = accent ?? tg.accent;
    final secondary = textSecondary ?? tg.textSecondary;
    final radius = BorderRadius.circular(TelegramRadii.mediaPreview);
    final domain = preview.siteName?.isNotEmpty == true
        ? preview.siteName!
        : preview.domainLabel;

    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tg.elevatedSurface.withValues(alpha: 0.55),
          borderRadius: radius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (preview.thumbnailBytes != null)
              _LinkPreviewThumbnail(bytes: preview.thumbnailBytes!),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    domain,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: TelegramFontSizes.bubbleMeta,
                      color: accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (preview.title != null && preview.title!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      preview.title!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: TelegramFontSizes.preview,
                        fontWeight: FontWeight.w600,
                        color: tg.textPrimary,
                      ),
                    ),
                  ],
                  if (preview.description != null &&
                      preview.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      preview.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: TelegramFontSizes.preview,
                        color: secondary,
                      ),
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

class _LinkPreviewThumbnail extends StatelessWidget {
  const _LinkPreviewThumbnail({required this.bytes});

  final List<int> bytes;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Image.memory(
        Uint8List.fromList(bytes),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}
