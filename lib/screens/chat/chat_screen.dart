import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/chat/chat_manager.dart';
import '../../models/chat_models.dart';
import '../../models/formatted_text.dart';
import '../../widgets/forward_messages_dialog.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/message_input_bar.dart';

/// Экран переписки: форматирование, ответ, пересылка, отложенная отправка.
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
      if (_controller.text.trim().isNotEmpty) {
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

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    final path = result?.files.single.path;
    if (path != null && mounted) {
      await context.read<ChatManager>().sendFile(path);
    }
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

  Future<void> _showMessageMenu(ChatMessage message) async {
    final manager = context.read<ChatManager>();
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
              leading: const Icon(Icons.forward),
              title: const Text('Переслать'),
              onTap: () => Navigator.pop(context, 'forward'),
            ),
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('Выбрать'),
              onTap: () => Navigator.pop(context, 'select'),
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
        manager.setReplyToMessage(message);
      case 'forward':
        manager.enterSelectionMode(initialMessageId: message.id);
        await _forwardSelected();
      case 'select':
        manager.enterSelectionMode(initialMessageId: message.id);
      case 'reschedule':
        await _rescheduleMessage(message);
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
    final typing = chatManager.typingStatus;
    final selectionMode = chatManager.isSelectionMode;

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
          if (selectionMode)
            IconButton(
              tooltip: 'Переслать',
              icon: const Icon(Icons.forward),
              onPressed: chatManager.selectedMessageCount > 0
                  ? _forwardSelected
                  : null,
            ),
        ],
        bottom: typing != null && !selectionMode
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
                    : messages.isEmpty
                        ? const Center(child: Text('Нет сообщений'))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              return MessageBubble(
                                message: message,
                                replyPreview:
                                    chatManager.replyPreviewFor(message),
                                selectionMode: selectionMode,
                                isSelected: chatManager.selectedMessageIds
                                    .contains(message.id),
                                onTap: selectionMode
                                    ? () => chatManager
                                        .toggleMessageSelection(message.id)
                                    : null,
                                onLongPress: selectionMode
                                    ? null
                                    : () => _showMessageMenu(message),
                              );
                            },
                          ),
          ),
          if (!selectionMode) ...[
            const Divider(height: 1),
            MessageInputBar(
              controller: _controller,
              onSend: _sendMessage,
              onAttach: _pickFile,
              onSchedule: _pickSchedule,
              replyDraft: chatManager.pendingReply,
              onClearReply: chatManager.clearReply,
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
              onVoiceAction: () => chatManager.sendChatAction(
                OutgoingChatAction.recordingVoice,
              ),
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
