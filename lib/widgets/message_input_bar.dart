import 'package:flutter/material.dart';

import '../core/theme/telegram_icons.dart';
import '../core/theme/telegram_theme.dart';
import '../models/formatted_text.dart';
import 'composer_attach_sheet.dart';
import 'sticker_panel_sheet.dart';

/// Поле ввода сообщения в стиле Telegram: панель, reply/edit, стикеры.
class MessageInputBar extends StatefulWidget {
  const MessageInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.onSchedule,
    this.chatId,
    this.replyDraft,
    this.onClearReply,
    this.editDraft,
    this.onClearEdit,
    this.scheduledAt,
    this.onClearSchedule,
    this.onFormatBold,
    this.onFormatItalic,
    this.onFormatCode,
    this.onFormatLink,
    this.onVoiceAction,
    this.onStickerPanelChanged,
    this.onPoll,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback? onPoll;
  final VoidCallback onSchedule;
  final int? chatId;
  final MessageReplyDraft? replyDraft;
  final VoidCallback? onClearReply;
  final MessageEditDraft? editDraft;
  final VoidCallback? onClearEdit;
  final DateTime? scheduledAt;
  final VoidCallback? onClearSchedule;
  final VoidCallback? onFormatBold;
  final VoidCallback? onFormatItalic;
  final VoidCallback? onFormatCode;
  final VoidCallback? onFormatLink;
  final VoidCallback? onVoiceAction;
  final ValueChanged<bool>? onStickerPanelChanged;

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  bool _stickerPanelOpen = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final next = widget.controller.text.trim().isNotEmpty;
    if (next != _hasText) {
      setState(() => _hasText = next);
    }
  }

  void _setStickerPanelOpen(bool open) {
    if (_stickerPanelOpen == open) {
      return;
    }
    setState(() => _stickerPanelOpen = open);
    widget.onStickerPanelChanged?.call(open);
  }

  void _toggleStickerPanel() {
    _setStickerPanelOpen(!_stickerPanelOpen);
  }

  Future<void> _openAttachSheet() async {
    final canShowStickerPanel = widget.chatId != null;
    final action = await ComposerAttachSheet.show(
      context,
      showPoll: widget.onPoll != null,
      showVoice: widget.onVoiceAction != null,
      showSticker: canShowStickerPanel,
      scheduledAt: widget.scheduledAt,
    );
    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case ComposerAttachAction.media:
        widget.onAttach();
      case ComposerAttachAction.poll:
        widget.onPoll?.call();
      case ComposerAttachAction.voice:
        widget.onVoiceAction?.call();
      case ComposerAttachAction.sticker:
        _setStickerPanelOpen(true);
      case ComposerAttachAction.schedule:
        widget.onSchedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    final canShowStickerPanel = widget.chatId != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tg.chatListBackground,
        border: Border(top: BorderSide(color: tg.chatListDivider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyDraft != null)
              _ComposerDraftBar(
                accentColor: tg.accent,
                title: widget.replyDraft!.authorName ?? 'Ответ',
                preview: widget.replyDraft!.preview,
                onClose: widget.onClearReply,
              ),
            if (widget.editDraft != null)
              _ComposerDraftBar(
                accentColor: tg.accent,
                title: widget.editDraft!.isCaption
                    ? 'Редактирование подписи'
                    : 'Редактирование',
                preview: widget.editDraft!.initialText,
                onClose: widget.onClearEdit,
              ),
            if (widget.scheduledAt != null)
              _ScheduleBar(
                scheduledAt: widget.scheduledAt!,
                onClose: widget.onClearSchedule,
              ),
            if (canShowStickerPanel)
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _stickerPanelOpen
                    ? StickerPanelPanel(
                        chatId: widget.chatId!,
                        height: TelegramSpacing.stickerPanelHeight,
                        onStickerSent: () => _setStickerPanelOpen(false),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _LeftInputButton(
                    stickerPanelOpen: _stickerPanelOpen,
                    canShowStickerPanel: canShowStickerPanel,
                    onEmojiOrKeyboard: canShowStickerPanel
                        ? _toggleStickerPanel
                        : null,
                    onAttach: canShowStickerPanel ? null : _openAttachSheet,
                  ),
                  Expanded(
                    child: _MessageTextField(
                      controller: widget.controller,
                      onSend: widget.onSend,
                      showAttachButton: canShowStickerPanel,
                      onAttach: canShowStickerPanel ? _openAttachSheet : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _RightInputButton(
                    hasText: _hasText,
                    editDraft: widget.editDraft,
                    scheduledAt: widget.scheduledAt,
                    onSend: widget.onSend,
                    onVoiceAction: widget.onVoiceAction,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeftInputButton extends StatelessWidget {
  const _LeftInputButton({
    required this.stickerPanelOpen,
    required this.canShowStickerPanel,
    this.onEmojiOrKeyboard,
    this.onAttach,
  });

  final bool stickerPanelOpen;
  final bool canShowStickerPanel;
  final VoidCallback? onEmojiOrKeyboard;
  final VoidCallback? onAttach;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;

    if (canShowStickerPanel && stickerPanelOpen) {
      return IconButton(
        tooltip: 'Клавиатура',
        onPressed: onEmojiOrKeyboard,
        icon: Icon(TelegramIcons.keyboard, color: tg.textSecondary),
        constraints: const BoxConstraints(
          minWidth: TelegramSpacing.inputTouchTarget,
          minHeight: TelegramSpacing.inputTouchTarget,
        ),
      );
    }

    if (canShowStickerPanel) {
      return IconButton(
        tooltip: 'Стикеры и GIF',
        onPressed: onEmojiOrKeyboard,
        icon: Icon(TelegramIcons.emoji, color: tg.textSecondary),
        constraints: const BoxConstraints(
          minWidth: TelegramSpacing.inputTouchTarget,
          minHeight: TelegramSpacing.inputTouchTarget,
        ),
      );
    }

    return IconButton(
      tooltip: 'Прикрепить',
      onPressed: onAttach,
      icon: Icon(TelegramIcons.attach, color: tg.textSecondary),
      constraints: const BoxConstraints(
        minWidth: TelegramSpacing.inputTouchTarget,
        minHeight: TelegramSpacing.inputTouchTarget,
      ),
    );
  }
}

class _MessageTextField extends StatelessWidget {
  const _MessageTextField({
    required this.controller,
    required this.onSend,
    this.showAttachButton = false,
    this.onAttach,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool showAttachButton;
  final VoidCallback? onAttach;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    final radius = BorderRadius.circular(TelegramRadii.inputField);

    return Container(
      decoration: BoxDecoration(
        color: tg.inputFieldBackground,
        borderRadius: radius,
      ),
      child: Row(
        children: [
          if (showAttachButton && onAttach != null)
            IconButton(
              tooltip: 'Прикрепить',
              onPressed: onAttach,
              icon: Icon(TelegramIcons.attach, color: tg.textSecondary, size: 22),
              padding: const EdgeInsets.only(left: 4),
              constraints: const BoxConstraints(
                minWidth: TelegramSpacing.inputTouchTarget,
                minHeight: TelegramSpacing.inputTouchTarget,
              ),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              style: TextStyle(
                color: tg.textPrimary,
                fontSize: TelegramFontSizes.message,
                height: TelegramLineHeights.message,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Сообщение',
                hintStyle: TextStyle(
                  color: tg.textSecondary,
                  fontSize: TelegramFontSizes.message,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RightInputButton extends StatelessWidget {
  const _RightInputButton({
    required this.hasText,
    this.editDraft,
    this.scheduledAt,
    required this.onSend,
    this.onVoiceAction,
  });

  final bool hasText;
  final MessageEditDraft? editDraft;
  final DateTime? scheduledAt;
  final VoidCallback onSend;
  final VoidCallback? onVoiceAction;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    final showSend = editDraft != null || hasText || scheduledAt != null;

    if (!showSend) {
      return IconButton(
        tooltip: 'Голосовое сообщение',
        onPressed: onVoiceAction,
        icon: Icon(TelegramIcons.mic, color: tg.textSecondary),
        constraints: const BoxConstraints(
          minWidth: TelegramSpacing.inputTouchTarget,
          minHeight: TelegramSpacing.inputTouchTarget,
        ),
      );
    }

    final icon = editDraft != null
        ? TelegramIcons.check
        : (scheduledAt != null ? TelegramIcons.scheduleSend : TelegramIcons.send);

    return Material(
      color: tg.accent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSend,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: TelegramSpacing.inputTouchTarget,
          height: TelegramSpacing.inputTouchTarget,
          child: Icon(icon, color: TelegramColors.unreadBadgeText, size: 22),
        ),
      ),
    );
  }
}

class _ComposerDraftBar extends StatelessWidget {
  const _ComposerDraftBar({
    required this.accentColor,
    required this.title,
    required this.preview,
    this.onClose,
  });

  final Color accentColor;
  final String title;
  final String preview;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: tg.chatListBackground,
        border: Border(
          left: BorderSide(color: accentColor, width: 2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: TelegramFontSizes.preview,
                    fontWeight: FontWeight.w600,
                    height: TelegramLineHeights.preview,
                  ),
                ),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tg.textSecondary,
                    fontSize: TelegramFontSizes.preview,
                    height: TelegramLineHeights.preview,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Отмена',
            onPressed: onClose,
            icon: Icon(TelegramIcons.close, size: 20, color: tg.textSecondary),
            constraints: const BoxConstraints(
              minWidth: TelegramSpacing.inputTouchTarget,
              minHeight: TelegramSpacing.inputTouchTarget,
            ),
            padding: const EdgeInsets.all(8),
          ),
        ],
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
    final tg = context.telegramTheme;
    final label =
        '${scheduledAt.day.toString().padLeft(2, '0')}.${scheduledAt.month.toString().padLeft(2, '0')} '
        '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: tg.chatListBackground,
        border: Border(
          left: BorderSide(color: tg.accent, width: 2),
        ),
      ),
      child: Row(
        children: [
          Icon(TelegramIcons.schedule, size: 18, color: tg.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Отправка: $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tg.textPrimary,
                fontSize: TelegramFontSizes.preview,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Отмена',
            onPressed: onClose,
            icon: Icon(TelegramIcons.close, size: 20, color: tg.textSecondary),
            constraints: const BoxConstraints(
              minWidth: TelegramSpacing.inputTouchTarget,
              minHeight: TelegramSpacing.inputTouchTarget,
            ),
            padding: const EdgeInsets.all(8),
          ),
        ],
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
