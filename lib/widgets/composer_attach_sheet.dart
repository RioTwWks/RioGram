import 'package:flutter/material.dart';

import '../core/theme/telegram_theme.dart';

/// Действие из TG-style attach sheet composer.
enum ComposerAttachAction {
  media,
  poll,
  voice,
  sticker,
  schedule,
}

/// Нижний лист вложений composer (§9.11): медиа, опрос, голос, стикер, отложенная отправка.
class ComposerAttachSheet extends StatelessWidget {
  const ComposerAttachSheet({
    super.key,
    this.showPoll = false,
    this.showVoice = false,
    this.showSticker = false,
    this.scheduledAt,
  });

  final bool showPoll;
  final bool showVoice;
  final bool showSticker;
  final DateTime? scheduledAt;

  static Future<ComposerAttachAction?> show(
    BuildContext context, {
    bool showPoll = false,
    bool showVoice = false,
    bool showSticker = false,
    DateTime? scheduledAt,
  }) {
    return showModalBottomSheet<ComposerAttachAction>(
      context: context,
      showDragHandle: true,
      builder: (_) => ComposerAttachSheet(
        showPoll: showPoll,
        showVoice: showVoice,
        showSticker: showSticker,
        scheduledAt: scheduledAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.attach_file, color: tg.textSecondary),
            title: Text('Медиа и файлы', style: TextStyle(color: tg.textPrimary)),
            subtitle: Text(
              'Фото, видео, документы, геолокация',
              style: TextStyle(color: tg.textSecondary),
            ),
            onTap: () => Navigator.pop(context, ComposerAttachAction.media),
          ),
          if (showPoll)
            ListTile(
              leading: Icon(Icons.poll_outlined, color: tg.textSecondary),
              title: Text('Опрос', style: TextStyle(color: tg.textPrimary)),
              onTap: () => Navigator.pop(context, ComposerAttachAction.poll),
            ),
          if (showVoice)
            ListTile(
              leading: Icon(Icons.mic_outlined, color: tg.textSecondary),
              title: Text('Голосовое', style: TextStyle(color: tg.textPrimary)),
              onTap: () => Navigator.pop(context, ComposerAttachAction.voice),
            ),
          if (showSticker)
            ListTile(
              leading: Icon(Icons.emoji_emotions_outlined, color: tg.textSecondary),
              title: Text('Стикер', style: TextStyle(color: tg.textPrimary)),
              onTap: () => Navigator.pop(context, ComposerAttachAction.sticker),
            ),
          ListTile(
            leading: Icon(Icons.schedule_outlined, color: tg.textSecondary),
            title: Text(
              scheduledAt != null
                  ? 'Изменить отложенную отправку'
                  : 'Отложить отправку',
              style: TextStyle(color: tg.textPrimary),
            ),
            onTap: () => Navigator.pop(context, ComposerAttachAction.schedule),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
