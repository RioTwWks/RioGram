import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/chat/chat_manager.dart';
import '../../core/theme/telegram_theme.dart';
import '../../widgets/date_separator.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/message_bubble_grouping.dart';
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
  int _lastMessageCount = 0;

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

    if (messages.isNotEmpty && messages.length != _lastMessageCount) {
      _lastMessageCount = messages.length;
      _scrollToBottom();
    }

    final tg = context.telegramTheme;
    final listEntries = MessageBubbleGrouping.buildListEntries(
      messages: messages,
      showSenderNamesInGroups: true,
    );

    return Scaffold(
      backgroundColor: tg.chatBackground,
      appBar: AppBar(
        backgroundColor: tg.chatListBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tg.textPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Комментарии',
                style: TextStyle(
                    fontSize: TelegramFontSizes.chatTitle,
                    fontWeight: FontWeight.w600,
                    color: tg.textPrimary)),
            Text(
              channelTitle,
              style: TextStyle(
                  fontSize: TelegramFontSizes.chatSubtitle,
                  color: tg.textSecondary),
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
                            itemCount: listEntries.length,
                            itemBuilder: (context, index) {
                              final entry = listEntries[index];
                              if (entry is ChatListDateEntry) {
                                return DateSeparator(date: entry.date);
                              }
                              final msgEntry = entry as ChatListMessageEntry;
                              final message = msgEntry.message;
                              return MessageBubble(
                                message: message,
                                showSenderName: msgEntry.showSenderName,
                                groupPosition: msgEntry.groupPosition,
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
