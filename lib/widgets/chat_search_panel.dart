import 'package:flutter/material.dart';

import '../core/chat/chat_manager.dart';
import '../models/chat_models.dart';
import 'chat_list_tile.dart';

/// Поле поиска по чатам и сообщениям.
class ChatSearchBar extends StatefulWidget {
  const ChatSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<ChatSearchBar> createState() => _ChatSearchBarState();
}

class _ChatSearchBarState extends State<ChatSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SearchBar(
        controller: widget.controller,
        hintText: 'Поиск',
        leading: const Icon(Icons.search),
        trailing: widget.controller.text.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onClear();
                  },
                ),
              ]
            : null,
        onChanged: widget.onChanged,
      ),
    );
  }
}

/// Результаты глобального поиска: чаты и сообщения.
class ChatSearchResults extends StatelessWidget {
  const ChatSearchResults({
    super.key,
    required this.chatManager,
    required this.onChatTap,
    required this.onMessageTap,
  });

  final ChatManager chatManager;
  final ValueChanged<int> onChatTap;
  final void Function(int chatId, int messageId) onMessageTap;

  @override
  Widget build(BuildContext context) {
    if (chatManager.isSearchLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chatManager.searchError != null) {
      return Center(child: Text(chatManager.searchError!));
    }

    final chats = chatManager.searchChatResults;
    final messages = chatManager.searchMessageResults;

    if (chats.isEmpty && messages.isEmpty) {
      return const Center(child: Text('Ничего не найдено'));
    }

    return ListView(
      children: [
        if (chats.isNotEmpty) ...[
          _SectionHeader(title: 'Чаты'),
          ...chats.map(
            (chat) => ChatListTile(
              chat: chat,
              selected: false,
              activeList: const ChatListMain(),
              onTap: () => onChatTap(chat.id),
            ),
          ),
        ],
        if (messages.isNotEmpty) ...[
          _SectionHeader(title: 'Сообщения'),
          ...messages.map(
            (hit) => ListTile(
              leading: const Icon(Icons.message_outlined),
              title: Text(
                hit.chatTitle ?? 'Чат ${hit.chatId}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                hit.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                formatChatListTime(hit.date),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              onTap: () => onMessageTap(hit.chatId, hit.messageId),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Быстрый доступ к «Избранному» (Saved Messages).
class SavedMessagesShortcut extends StatelessWidget {
  const SavedMessagesShortcut({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.bookmark,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: const Text(
        'Избранное',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: const Text('Сохранённые сообщения'),
      onTap: onTap,
    );
  }
}
