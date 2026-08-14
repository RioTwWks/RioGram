import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/chat/chat_manager.dart';
import '../../models/chat_models.dart';
import '../../models/formatted_text.dart';
import '../../models/media_models.dart';
import '../../widgets/forward_messages_dialog.dart';
import '../../widgets/media_attach_sheet.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/message_input_bar.dart';
import '../../widgets/message_reactions_row.dart';
import '../../widgets/poll_message_body.dart';
import '../../widgets/voice_recorder_sheet.dart';
import 'media_viewer_screen.dart';

/// Экран переписки: форматирование, ответ, пересылка, редактирование, удаление.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    this.closeOnDispose = true,
  });

  final int chatId;
  final bool closeOnDispose;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manager = context.read<ChatManager>();
      if (manager.activeChatId != widget.chatId) {
        manager.openChat(widget.chatId);
      }
    });
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    _scrollController.dispose();
    if (widget.closeOnDispose) {
      context.read<ChatManager>().closeChat();
    }
    super.dispose();
  }

  void _onTextChanged() {
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 400), () {
      if (_controller.text.trim().isNotEmpty &&
          context.read<ChatManager>().editingMessage == null) {
        context.read<ChatManager>().sendTypingAction();
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      return;
    }
    context.read<ChatManager>().sendText(text);
    _controller.clear();
    _scrollToBottom();
  }

  void _clearComposer({bool clearText = true}) {
    if (clearText) {
      _controller.clear();
    }
    final manager = context.read<ChatManager>();
    manager.cancelEditing();
    manager.clearReply();
    manager.clearScheduledSendAt();
  }

  Future<void> _attachMedia() async {
    final action = await MediaAttachSheet.show(context);
    if (action == null || !mounted) {
      return;
    }

    final manager = context.read<ChatManager>();
    switch (action) {
      case MediaAttachAction.photoCompressed:
        final photo = await FilePicker.platform.pickFiles(type: FileType.image);
        final photoPath = photo?.files.single.path;
        if (photoPath != null) {
          await manager.sendPhoto(photoPath);
        }
      case MediaAttachAction.photoAsFile:
        final photoFile = await FilePicker.platform.pickFiles(type: FileType.image);
        final photoFilePath = photoFile?.files.single.path;
        if (photoFilePath != null) {
          await manager.sendDocument(photoFilePath);
        }
      case MediaAttachAction.videoCompressed:
        final video = await FilePicker.platform.pickFiles(type: FileType.video);
        final videoPath = video?.files.single.path;
        if (videoPath != null) {
          await manager.sendVideo(videoPath);
        }
      case MediaAttachAction.videoAsFile:
        final videoFile = await FilePicker.platform.pickFiles(type: FileType.video);
        final videoFilePath = videoFile?.files.single.path;
        if (videoFilePath != null) {
          await manager.sendDocument(videoFilePath);
        }
      case MediaAttachAction.videoNote:
        final note = await FilePicker.platform.pickFiles(type: FileType.video);
        final notePath = note?.files.single.path;
        if (notePath != null) {
          await manager.sendVideoNote(notePath);
        }
      case MediaAttachAction.album:
        final album = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.media,
        );
        final paths = album?.files
                .map((file) => file.path)
                .whereType<String>()
                .toList() ??
            [];
        if (paths.isNotEmpty) {
          await manager.sendMediaAlbum(paths);
        }
      case MediaAttachAction.document:
        final doc = await FilePicker.platform.pickFiles();
        final docPath = doc?.files.single.path;
        if (docPath != null) {
          await manager.sendDocument(docPath);
        }
      case MediaAttachAction.audio:
        final audio = await FilePicker.platform.pickFiles(type: FileType.audio);
        final audioPath = audio?.files.single.path;
        if (audioPath != null) {
          await manager.sendAudio(audioPath);
        }
    }
  }

  Future<void> _recordVoice() async {
    final manager = context.read<ChatManager>();
    manager.sendChatAction(OutgoingChatAction.recordingVoice);
    final result = await VoiceRecorderSheet.show(context);
    manager.sendChatAction(OutgoingChatAction.cancel);
    if (result == null || !mounted) {
      return;
    }
    await manager.sendVoiceNote(
      path: result.path,
      durationSeconds: result.durationSeconds,
      waveform: result.waveform,
    );
  }

  void _openMediaViewer(ChatMessage anchor) {
    final manager = context.read<ChatManager>();
    final items = manager.messages
        .where((message) => MediaAlbumGrouper.isMediaKind(message.content.kind))
        .map(MediaViewerItem.fromMessage)
        .where((item) => item.hasLocalFile)
        .toList();
    if (items.isEmpty) {
      return;
    }

    var initialIndex = items.indexWhere((item) => item.messageId == anchor.id);
    if (initialIndex < 0) {
      initialIndex = 0;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaViewerScreen(
          items: items,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) {
      return;
    }

    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    context.read<ChatManager>().setScheduledSendAt(scheduled);
  }

  Future<void> _createPoll() async {
    final data = await PollComposeDialog.show(context);
    if (data == null || !mounted) {
      return;
    }
    context.read<ChatManager>().sendPoll(
          question: data.question,
          options: data.options,
          kind: data.kind,
          correctOptionId: data.correctOptionId,
        );
  }

  Future<void> _addReactionToMessage(ChatMessage message) async {
    final emoji = await ReactionPickerSheet.show(context);
    if (emoji == null || !mounted) {
      return;
    }
    context.read<ChatManager>().addMessageReaction(message.id, emoji);
  }

  Future<void> _showMessageMenu(ChatMessage message) async {
    final manager = context.read<ChatManager>();
    final canEdit = message.canEditText || message.canEditCaption;
    final hasMedia = message.mediaFileId != null;
    final hasLocalMedia = message.localFilePath != null;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Ответить'),
              onTap: () => Navigator.pop(context, 'reply'),
            ),
            ListTile(
              leading: const Icon(Icons.add_reaction_outlined),
              title: const Text('Реакция'),
              onTap: () => Navigator.pop(context, 'react'),
            ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(
                  message.canEditCaption && !message.canEditText
                      ? 'Редактировать подпись'
                      : 'Редактировать',
                ),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Переслать'),
              onTap: () => Navigator.pop(context, 'forward'),
            ),
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('Выбрать'),
              onTap: () => Navigator.pop(context, 'select'),
            ),
            if (hasMedia && !hasLocalMedia)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Скачать'),
                onTap: () => Navigator.pop(context, 'download'),
              ),
            if (hasLocalMedia)
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text('Удалить из кэша'),
                onTap: () => Navigator.pop(context, 'delete_cache'),
              ),
            if (message.canBeDeletedOnlyForSelf)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Удалить у себя'),
                onTap: () => Navigator.pop(context, 'delete_self'),
              ),
            if (message.canBeDeletedForAllUsers)
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined),
                title: const Text('Удалить для всех'),
                onTap: () => Navigator.pop(context, 'delete_all'),
              ),
            if (message.schedulingInfo != null)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Изменить время отправки'),
                onTap: () => Navigator.pop(context, 'reschedule'),
              ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case 'reply':
        _clearComposer();
        manager.setReplyToMessage(message);
      case 'react':
        await _addReactionToMessage(message);
      case 'edit':
        _clearComposer(clearText: false);
        _controller.text = message.editableComposerText ?? '';
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
        manager.startEditingMessage(message);
      case 'forward':
        manager.enterSelectionMode(initialMessageId: message.id);
        await _forwardSelected();
      case 'select':
        manager.enterSelectionMode(initialMessageId: message.id);
      case 'download':
        manager.downloadMessageMedia(message);
      case 'delete_cache':
        manager.deleteMessageFromCache(message);
      case 'delete_self':
        manager.deleteMessage(message.id, revoke: false);
      case 'delete_all':
        final confirmed = await _confirmDeleteForAll(1);
        if (confirmed && mounted) {
          manager.deleteMessage(message.id, revoke: true);
        }
      case 'reschedule':
        await _rescheduleMessage(message);
    }
  }

  Future<bool> _confirmDeleteForAll(int count) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить для всех?'),
        content: Text(
          count == 1
              ? 'Сообщение будет удалено у всех участников чата.'
              : 'Выбранные сообщения ($count) будут удалены у всех участников.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteSelected() async {
    final manager = context.read<ChatManager>();
    if (manager.selectedMessageCount == 0) {
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (manager.canDeleteSelectedForSelf)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Удалить у себя'),
                onTap: () => Navigator.pop(context, 'self'),
              ),
            if (manager.canDeleteSelectedForAll)
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined),
                title: const Text('Удалить для всех'),
                onTap: () => Navigator.pop(context, 'all'),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Отмена'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == 'all') {
      final confirmed = await _confirmDeleteForAll(manager.selectedMessageCount);
      if (!confirmed || !mounted) {
        return;
      }
      manager.deleteSelectedMessages(revoke: true);
    } else if (action == 'self') {
      manager.deleteSelectedMessages(revoke: false);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сообщения удалены')),
      );
    }
  }

  Future<void> _rescheduleMessage(ChatMessage message) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: message.schedulingInfo is MessageSchedulingAtDate
          ? (message.schedulingInfo! as MessageSchedulingAtDate).sendAt
          : now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) {
      return;
    }

    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    context.read<ChatManager>().rescheduleMessage(
          message.chatId,
          message.id,
          scheduled,
        );
  }

  Future<void> _forwardSelected() async {
    final manager = context.read<ChatManager>();
    if (manager.selectedMessageCount == 0) {
      return;
    }

    final targetChatId = await ForwardMessagesDialog.show(
      context,
      messageCount: manager.selectedMessageCount,
    );
    if (targetChatId == null || !mounted) {
      return;
    }

    final options = await ForwardOptionsDialog.show(context);
    if (options == null || !mounted) {
      manager.exitSelectionMode();
      return;
    }

    manager.forwardSelectedMessages(
      toChatId: targetChatId,
      withoutAuthor: options.withoutAuthor,
      removeCaption: options.removeCaption,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сообщения пересланы')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatManager = context.watch<ChatManager>();
    final chat = chatManager.activeChat;
    final messages = chatManager.messages;
    final listItems = MediaAlbumGrouper.group(messages);
    final typing = chatManager.typingStatus;
    final selectionMode = chatManager.isSelectionMode;
    final editing = chatManager.editingMessage;
    final showViewCount = chat?.kind == ChatKind.channel;

    if (messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectionMode
              ? 'Выбрано: ${chatManager.selectedMessageCount}'
              : (chat?.title ?? 'Чат'),
        ),
        leading: selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: chatManager.exitSelectionMode,
              )
            : null,
        actions: [
          if (selectionMode) ...[
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: chatManager.selectedMessageCount > 0 &&
                      (chatManager.canDeleteSelectedForSelf ||
                          chatManager.canDeleteSelectedForAll)
                  ? _deleteSelected
                  : null,
            ),
            IconButton(
              tooltip: 'Переслать',
              icon: const Icon(Icons.forward),
              onPressed: chatManager.selectedMessageCount > 0
                  ? _forwardSelected
                  : null,
            ),
          ],
        ],
        bottom: typing != null && !selectionMode && editing == null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Text(
                      typing,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: chatManager.isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : chatManager.messagesError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            chatManager.messagesError!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : listItems.isEmpty
                        ? const Center(child: Text('Нет сообщений'))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: listItems.length,
                            itemBuilder: (context, index) {
                              final item = listItems[index];
                              final message = item.primary;
                              final album = item is AlbumChatMessageItem
                                  ? item.albumMessages
                                  : null;
                              return MessageBubble(
                                message: message,
                                albumMessages: album,
                                replyPreview:
                                    chatManager.replyPreviewFor(message),
                                selectionMode: selectionMode,
                                showViewCount: showViewCount,
                                isSelected: chatManager.selectedMessageIds
                                    .contains(message.id),
                                onTap: selectionMode
                                    ? () => chatManager
                                        .toggleMessageSelection(message.id)
                                    : null,
                                onLongPress: selectionMode
                                    ? null
                                    : () => _showMessageMenu(message),
                                onReactionTap: (emoji) => chatManager
                                    .toggleMessageReaction(message.id, emoji),
                                onAddReaction: () =>
                                    _addReactionToMessage(message),
                                onPollVote: (optionId) => chatManager
                                    .setPollAnswer(message.id, [optionId]),
                                onInlineButtonTap: (button) {
                                  if (button.callbackData != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Callback: ${button.callbackData}',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                onMediaTap: selectionMode
                                    ? null
                                    : _openMediaViewer,
                                onCancelTransfer: message.fileTransfer != null
                                    ? () => chatManager
                                        .cancelMessageTransfer(message)
                                    : null,
                              );
                            },
                          ),
          ),
          if (!selectionMode) ...[
            const Divider(height: 1),
            MessageInputBar(
              controller: _controller,
              onSend: _sendMessage,
              onAttach: _attachMedia,
              onPoll: _createPoll,
              onSchedule: _pickSchedule,
              replyDraft: chatManager.pendingReply,
              onClearReply: chatManager.clearReply,
              editDraft: editing,
              onClearEdit: () {
                chatManager.cancelEditing();
                _controller.clear();
              },
              scheduledAt: chatManager.scheduledSendAt,
              onClearSchedule: chatManager.clearScheduledSendAt,
              onFormatBold: () =>
                  ComposerFormatting.wrapSelection(_controller, '**', '**'),
              onFormatItalic: () =>
                  ComposerFormatting.wrapSelection(_controller, '*', '*'),
              onFormatCode: () =>
                  ComposerFormatting.wrapSelection(_controller, '`', '`'),
              onFormatLink: () =>
                  ComposerFormatting.insertLink(context, _controller),
              onVoiceAction: _recordVoice,
              onStickerAction: () => chatManager.sendChatAction(
                OutgoingChatAction.choosingSticker,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
