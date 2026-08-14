import 'package:flutter/material.dart';

import '../models/formatted_text.dart';

/// Поле ввода сообщения с форматированием, ответом и отложенной отправкой.
class MessageInputBar extends StatelessWidget {
  const MessageInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.onSchedule,
    this.replyDraft,
    this.onClearReply,
    this.scheduledAt,
    this.onClearSchedule,
    this.onFormatBold,
    this.onFormatItalic,
    this.onFormatCode,
    this.onFormatLink,
    this.onVoiceAction,
    this.onStickerAction,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onSchedule;
  final MessageReplyDraft? replyDraft;
  final VoidCallback? onClearReply;
  final DateTime? scheduledAt;
  final VoidCallback? onClearSchedule;
  final VoidCallback? onFormatBold;
  final VoidCallback? onFormatItalic;
  final VoidCallback? onFormatCode;
  final VoidCallback? onFormatLink;
  final VoidCallback? onVoiceAction;
  final VoidCallback? onStickerAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyDraft != null)
            _ReplyBar(
              draft: replyDraft!,
              onClose: onClearReply,
            ),
          if (scheduledAt != null)
            _ScheduleBar(
              scheduledAt: scheduledAt!,
              onClose: onClearSchedule,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Жирный (**)',
                  onPressed: onFormatBold,
                  icon: const Icon(Icons.format_bold),
                ),
                IconButton(
                  tooltip: 'Курсив (*)',
                  onPressed: onFormatItalic,
                  icon: const Icon(Icons.format_italic),
                ),
                IconButton(
                  tooltip: 'Код (`)',
                  onPressed: onFormatCode,
                  icon: const Icon(Icons.code),
                ),
                IconButton(
                  tooltip: 'Ссылка [текст](url)',
                  onPressed: onFormatLink,
                  icon: const Icon(Icons.link),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Голосовое (action)',
                  onPressed: onVoiceAction,
                  icon: const Icon(Icons.mic_none),
                ),
                IconButton(
                  tooltip: 'Стикер (action)',
                  onPressed: onStickerAction,
                  icon: const Icon(Icons.emoji_emotions_outlined),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Прикрепить',
                  onSelected: (value) {
                    switch (value) {
                      case 'file':
                        onAttach();
                      case 'voice':
                        onVoiceAction?.call();
                      case 'sticker':
                        onStickerAction?.call();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'file', child: Text('Файл')),
                    PopupMenuItem(value: 'voice', child: Text('Голосовое')),
                    PopupMenuItem(value: 'sticker', child: Text('Стикер')),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.attach_file),
                  ),
                ),
                IconButton(
                  tooltip: 'Отложить отправку',
                  onPressed: onSchedule,
                  icon: Icon(
                    Icons.schedule,
                    color: scheduledAt != null ? theme.colorScheme.primary : null,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: const InputDecoration(
                      hintText: 'Сообщение (**жирный**, *курсив*, @user, #tag)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: scheduledAt != null ? 'Запланировать' : 'Отправить',
                  onPressed: onSend,
                  icon: Icon(scheduledAt != null ? Icons.schedule_send : Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.draft,
    this.onClose,
  });

  final MessageReplyDraft draft;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.reply),
        title: Text(
          draft.authorName ?? 'Ответ',
          style: theme.textTheme.labelLarge,
        ),
        subtitle: Text(
          draft.preview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onClose,
        ),
      ),
    );
  }
}

class _ScheduleBar extends StatelessWidget {
  const _ScheduleBar({
    required this.scheduledAt,
    this.onClose,
  });

  final DateTime scheduledAt;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label =
        '${scheduledAt.day.toString().padLeft(2, '0')}.${scheduledAt.month.toString().padLeft(2, '0')} '
        '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}';

    return Material(
      color: theme.colorScheme.primaryContainer,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.schedule),
        title: Text('Отправка: $label'),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onClose,
        ),
      ),
    );
  }
}

/// Оборачивает выделение в markdown-разметку composer.
class ComposerFormatting {
  const ComposerFormatting._();

  static void wrapSelection(
    TextEditingController controller,
    String prefix,
    String suffix,
  ) {
    final selection = controller.selection;
    if (!selection.isValid) {
      return;
    }

    final text = controller.text;
    if (selection.isCollapsed) {
      final wrapped = '$prefix$suffix';
      final newText = text.replaceRange(selection.start, selection.end, wrapped);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + prefix.length),
      );
      return;
    }

    final selected = text.substring(selection.start, selection.end);
    final wrapped = '$prefix$selected$suffix';
    final newText = text.replaceRange(selection.start, selection.end, wrapped);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: selection.start,
        extentOffset: selection.start + wrapped.length,
      ),
    );
  }

  static Future<void> insertLink(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final urlController = TextEditingController(text: 'https://');
    final labelController = TextEditingController();
    final result = await showDialog<({String label, String url})>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Вставить ссылку'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Текст'),
              ),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'URL'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                (
                  label: labelController.text.trim(),
                  url: urlController.text.trim(),
                ),
              ),
              child: const Text('Вставить'),
            ),
          ],
        );
      },
    );

    urlController.dispose();
    labelController.dispose();

    if (result == null || result.label.isEmpty || result.url.isEmpty) {
      return;
    }

    final snippet = '[${result.label}](${result.url})';
    final selection = controller.selection;
    final text = controller.text;
    final insertAt = selection.isValid ? selection.start : text.length;
    final newText = text.replaceRange(insertAt, selection.end, snippet);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertAt + snippet.length),
    );
  }
}
