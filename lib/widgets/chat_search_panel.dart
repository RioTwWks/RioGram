import 'package:flutter/material.dart';

import '../core/chat/chat_manager.dart';
import '../core/search/search_manager.dart';
import '../core/theme/telegram_theme.dart';
import '../models/chat_models.dart';
import '../models/search_models.dart';
import 'chat_list_tile.dart';

/// Поле поиска по чатам и сообщениям.
class ChatSearchBar extends StatefulWidget {
  const ChatSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.focusNode,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final FocusNode? focusNode;

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
    final tg = context.telegramTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tg.searchFieldBackground,
          borderRadius: BorderRadius.circular(TelegramRadii.searchField),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          onChanged: widget.onChanged,
          style: TextStyle(
            color: tg.textPrimary,
            fontSize: TelegramFontSizes.preview,
          ),
          decoration: InputDecoration(
            hintText: 'Поиск',
            hintStyle: TextStyle(color: tg.textSecondary),
            prefixIcon: Icon(Icons.search, color: tg.textSecondary, size: 20),
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close, color: tg.textSecondary, size: 20),
                    onPressed: () {
                      widget.controller.clear();
                      widget.onClear();
                    },
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            isDense: true,
          ),
        ),
      ),
    );
  }
}

/// Фильтры типа сообщений для поиска.
class SearchFilterChips extends StatelessWidget {
  const SearchFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final SearchMessageFilterKind selected;
  final ValueChanged<SearchMessageFilterKind> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: SearchMessageFilterKind.values.map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter.label),
              selected: selected == filter,
              onSelected: (_) => onSelected(filter),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Результаты глобального поиска.
class ChatSearchResults extends StatelessWidget {
  const ChatSearchResults({
    super.key,
    required this.searchManager,
    required this.chatManager,
    required this.onChatTap,
    required this.onMessageTap,
    required this.onUserTap,
  });

  final SearchManager searchManager;
  final ChatManager chatManager;
  final ValueChanged<int> onChatTap;
  final void Function(int chatId, int messageId) onMessageTap;
  final ValueChanged<int> onUserTap;

  @override
  Widget build(BuildContext context) {
    if (searchManager.isGlobalLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchManager.globalError != null) {
      return Center(child: Text(searchManager.globalError!));
    }

    final chats = searchManager.globalChatIds
        .map((id) => chatManager.chatById(id))
        .whereType<ChatSummary>()
        .toList();
    final publicChats = searchManager.publicChatIds
        .where((id) => !searchManager.globalChatIds.contains(id))
        .map((id) => chatManager.chatById(id))
        .whereType<ChatSummary>()
        .toList();
    final messages = searchManager.globalMessageResults;
    final user = searchManager.globalUserHit;

    if (chats.isEmpty &&
        publicChats.isEmpty &&
        messages.isEmpty &&
        user == null) {
      return const Center(child: Text('Ничего не найдено'));
    }

    return ListView(
      children: [
        if (user != null) ...[
          const _SectionHeader(title: 'Пользователь'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(user.displayName),
            subtitle: user.username != null ? Text('@${user.username}') : null,
            onTap: () => onUserTap(user.userId),
          ),
        ],
        if (chats.isNotEmpty) ...[
          const _SectionHeader(title: 'Чаты'),
          ...chats.map(
            (chat) => ChatListTile(
              chat: chat,
              selected: false,
              activeList: const ChatListMain(),
              onTap: () => onChatTap(chat.id),
            ),
          ),
        ],
        if (publicChats.isNotEmpty) ...[
          const _SectionHeader(title: 'Каналы и боты'),
          ...publicChats.map(
            (chat) => ChatListTile(
              chat: chat,
              selected: false,
              activeList: const ChatListMain(),
              onTap: () => onChatTap(chat.id),
            ),
          ),
        ],
        if (messages.isNotEmpty) ...[
          const _SectionHeader(title: 'Сообщения'),
          ...messages.map(
            (hit) => ListTile(
              leading: const Icon(Icons.message_outlined),
              title: Text(
                hit.chatTitle ??
                    searchManager.chatTitleFor(hit.chatId) ??
                    'Чат ${hit.chatId}',
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
          if (searchManager.globalHasMoreMessages)
            Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton(
                onPressed: searchManager.isGlobalLoadingMore
                    ? null
                    : searchManager.loadMoreGlobalMessages,
                child: searchManager.isGlobalLoadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Показать ещё'),
              ),
            ),
        ],
      ],
    );
  }
}

/// Результаты поиска сообщений внутри чата.
class ChatMessageSearchResults extends StatelessWidget {
  const ChatMessageSearchResults({
    super.key,
    required this.state,
    required this.onMessageTap,
    required this.onLoadMore,
  });

  final ChatMessageSearchState state;
  final ValueChanged<int> onMessageTap;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(child: Text(state.error!));
    }

    if (!state.isActive) {
      return const Center(child: Text('Введите запрос'));
    }

    if (state.results.isEmpty) {
      return const Center(child: Text('Сообщения не найдены'));
    }

    return ListView.builder(
      itemCount: state.results.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.results.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton(
              onPressed: state.isLoadingMore ? null : onLoadMore,
              child: state.isLoadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Показать ещё'),
            ),
          );
        }

        final hit = state.results[index];
        return ListTile(
          leading: const Icon(Icons.message_outlined),
          title: Text(
            hit.preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            formatChatListTime(hit.date),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          onTap: () => onMessageTap(hit.messageId),
        );
      },
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
