import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/chat/chat_manager.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/message_input_bar.dart';

/// Комментарии к посту канала (связанная группа-обсуждение).
class MessageThreadScreen extends StatefulWidget {
  const MessageThreadScreen({
    super.key,
    required this.channelChatId,
    required this.channelMessageId,
    this.postPreview,
  });

  final int channelChatId;
  final int channelMessageId;
  final String? postPreview;

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatManager>().fetchMessageThread(
            widget.channelChatId,
            widget.channelMessageId,
            postPreview: widget.postPreview,
          );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    context.read<ChatManager>().clearMessageThread();
    super.dispose();
  }

  void _sendComment() {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      return;
    }
    context.read<ChatManager>().sendThreadMessage(text);
    _controller.clear();
    _scrollToBottom();
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
    final manager = context.watch<ChatManager>();
    final messages = manager.messageThreadMessages;
    final contextInfo = manager.messageThreadContext;
    final channelTitle =
        manager.chatById(widget.channelChatId)?.title ?? 'Канал';

    if (messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Комментарии'),
            Text(
              channelTitle,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.postPreview != null && widget.postPreview!.isNotEmpty)
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      size: 18,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.postPreview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: manager.isLoadingMessageThread
                ? const Center(child: CircularProgressIndicator())
                : manager.messageThreadError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            manager.messageThreadError!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : messages.isEmpty
                        ? const Center(child: Text('Пока нет комментариев'))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              return MessageBubble(
                                message: message,
                                showSenderName: true,
                                replyPreview:
                                    manager.replyPreviewFor(message),
                              );
                            },
                          ),
          ),
          if (contextInfo != null) ...[
            MessageInputBar(
              chatId: widget.channelChatId,
              controller: _controller,
              onSend: _sendComment,
              onAttach: () {},
              onSchedule: () {},
              onVoiceAction: null,
            ),
          ],
        ],
      ),
    );
  }
}
