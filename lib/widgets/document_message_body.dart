import 'package:flutter/material.dart';

import '../core/theme/telegram_theme.dart';
import '../models/audio_models.dart';

/// Компактная карточка документа: иконка типа файла, имя и размер.
class DocumentMessageBody extends StatelessWidget {
  const DocumentMessageBody({
    super.key,
    required this.fileName,
    this.documentInfo,
  });

  final String fileName;
  final DocumentFileInfo? documentInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tg = context.telegramTheme;
    final icon = _iconForFileName(fileName);
    final sizeLabel = documentInfo?.sizeLabel;

    return Container(
      constraints: const BoxConstraints(
        minWidth: 200,
        maxWidth: 280,
        minHeight: TelegramMediaSpacing.documentCardMinHeight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tg.elevatedSurface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(TelegramRadii.mediaPreview),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tg.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(TelegramRadii.buttonPill),
            ),
            child: Icon(icon, color: tg.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tg.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (sizeLabel != null && sizeLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sizeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: tg.textTime,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconForFileName(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'doc' || 'docx' || 'odt' || 'rtf' => Icons.description_outlined,
      'xls' || 'xlsx' || 'ods' || 'csv' => Icons.table_chart_outlined,
      'ppt' || 'pptx' || 'odp' => Icons.slideshow_outlined,
      'zip' || 'rar' || '7z' || 'tar' || 'gz' => Icons.folder_zip_outlined,
      'mp3' || 'wav' || 'flac' || 'aac' || 'ogg' => Icons.music_note_outlined,
      'mp4' || 'mov' || 'avi' || 'mkv' || 'webm' => Icons.movie_outlined,
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'bmp' =>
        Icons.image_outlined,
      'txt' || 'md' => Icons.text_snippet_outlined,
      'apk' => Icons.android_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }
}
