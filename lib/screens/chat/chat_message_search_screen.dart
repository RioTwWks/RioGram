import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/chat/chat_manager.dart';
import '../../core/search/search_manager.dart';
import '../../widgets/chat_search_panel.dart';

/// Поиск сообщений внутри одного чата.
class ChatMessageSearchScreen extends StatefulWidget {
  const ChatMessageSearchScreen({
    super.key,
    required this.chatId,
    this.chatTitle,
    this.forumTopicId,
  });

  final int chatId;
  final String? chatTitle;
  final int? forumTopicId;

  @override
  State<ChatMessageSearchScreen> createState() =>
      _ChatMessageSearchScreenState();
}

class _ChatMessageSearchScreenState extends State<ChatMessageSearchScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SearchManager>().clearChatSearch();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    context.read<SearchManager>().clearChatSearch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchManager>();
    final chatManager = context.read<ChatManager>();
    final state = search.chatSearchState;
    final title = widget.chatTitle ?? chatManager.chatById(widget.chatId)?.title;

    return Scaffold(
      appBar: AppBar(
        title: Text('Поиск${title != null ? ' · $title' : ''}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SearchBar(
              controller: _controller,
              hintText: 'Поиск в чате',
              leading: const Icon(Icons.search_outlined),
              trailing: _controller.text.isNotEmpty
                  ? [
                      IconButton(
                        icon: const Icon(Icons.close_outlined),
                        onPressed: () {
                          _controller.clear();
                          search.clearChatSearch();
                        },
                      ),
                    ]
                  : null,
              onChanged: (value) {
                search.setChatSearchQuery(
                  widget.chatId,
                  value,
                  forumTopicId: widget.forumTopicId,
                );
              },
            ),
          ),
          SearchFilterChips(
            selected: state.filter,
            onSelected: search.setChatSearchFilter,
          ),
          Expanded(
            child: ChatMessageSearchResults(
              state: state,
              onMessageTap: (messageId) {
                chatManager.openChatAtMessage(widget.chatId, messageId);
                Navigator.of(context).pop();
              },
              onLoadMore: search.loadMoreChatMessages,
            ),
          ),
        ],
      ),
    );
  }
}
