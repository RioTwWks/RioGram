import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/chat/chat_manager.dart';
import '../../models/chat_models.dart';
import '../../widgets/chat_list_tile.dart';
import '../../widgets/chat_search_panel.dart';
import '../../widgets/proxy_status_indicator.dart';
import '../chat/chat_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/proxy/proxy_manager.dart';

/// Адаптивный экран: список чатов и переписка (master-detail на широких экранах).
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  int? _selectedChatId;
  final _searchController = TextEditingController();

  static const _wideBreakpoint = 720.0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatManager = context.watch<ChatManager>();
    final proxy = context.watch<ProxyManager?>();
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    if (isWide) {
      return _buildWideLayout(context, chatManager, proxy);
    }
    return _buildNarrowLayout(context, chatManager, proxy);
  }

  Widget _buildNarrowLayout(
    BuildContext context,
    ChatManager chatManager,
    ProxyManager? proxy,
  ) {
    return Scaffold(
      appBar: _buildAppBar(context, chatManager, proxy, showBack: false),
      body: _buildChatListBody(context, chatManager),
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    ChatManager chatManager,
    ProxyManager? proxy,
  ) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 360,
            child: Column(
              children: [
                Material(
                  elevation: 1,
                  child: SafeArea(
                    bottom: false,
                    child: _buildToolbar(context, chatManager, proxy),
                  ),
                ),
                Expanded(child: _buildChatListBody(context, chatManager)),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _selectedChatId == null
                ? const Center(
                    child: Text('Выберите чат'),
                  )
                : ChatScreen(
                    key: ValueKey(_selectedChatId),
                    chatId: _selectedChatId!,
                    closeOnDispose: false,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatListBody(BuildContext context, ChatManager chatManager) {
    return Column(
      children: [
        ChatSearchBar(
          controller: _searchController,
          onChanged: chatManager.setSearchQuery,
          onClear: chatManager.clearSearch,
        ),
        if (!chatManager.isSearchActive) ...[
          ChatListTabs(
            activeList: chatManager.activeChatList,
            folders: chatManager.chatFolders,
            onSelected: chatManager.switchChatList,
          ),
          const Divider(height: 1),
        ],
        Expanded(
          child: chatManager.isSearchActive
              ? ChatSearchResults(
                  chatManager: chatManager,
                  onChatTap: (chatId) => _openChat(context, chatManager, chatId),
                  onMessageTap: (chatId, messageId) {
                    chatManager.openChatAtMessage(chatId, messageId);
                    _openChat(context, chatManager, chatId);
                  },
                )
              : _ChatsList(
                  chatManager: chatManager,
                  selectedChatId: _selectedChatId,
                  showSavedMessagesShortcut:
                      chatManager.activeChatList is ChatListMain &&
                          chatManager.savedMessagesChatId != null,
                  onSavedMessagesTap: () {
                    final chatId = chatManager.savedMessagesChatId;
                    if (chatId != null) {
                      _openChat(context, chatManager, chatId);
                    }
                  },
                  onChatTap: (chatId) => _openChat(context, chatManager, chatId),
                ),
        ),
      ],
    );
  }

  void _openChat(BuildContext context, ChatManager chatManager, int chatId) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    if (isWide) {
      setState(() => _selectedChatId = chatId);
      chatManager.openChat(chatId);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(chatId: chatId),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ChatManager chatManager,
    ProxyManager? proxy, {
    required bool showBack,
  }) {
    return AppBar(
      title: const Text('Чаты'),
      automaticallyImplyLeading: showBack,
      actions: _buildAppBarActions(context, chatManager, proxy),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    ChatManager chatManager,
    ProxyManager? proxy,
  ) {
    return SizedBox(
      height: kToolbarHeight,
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Expanded(
            child: Text('Чаты', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          ),
          ..._buildAppBarActions(context, chatManager, proxy),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions(
    BuildContext context,
    ChatManager chatManager,
    ProxyManager? proxy,
  ) {
    return [
      if (chatManager.savedMessagesChatId != null)
        IconButton(
          tooltip: 'Избранное',
          onPressed: () {
            final chatId = chatManager.savedMessagesChatId;
            if (chatId != null) {
              _openChat(context, chatManager, chatId);
            }
          },
          icon: const Icon(Icons.bookmark_outline),
        ),
      if (proxy != null)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Center(
            child: ProxyStatusIndicator(
              status: proxy.status,
              proxyName: proxy.activeProxyName,
            ),
          ),
        ),
      IconButton(
        tooltip: 'Настройки',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SettingsScreen(),
            ),
          );
        },
        icon: const Icon(Icons.settings),
      ),
    ];
  }
}

class _ChatsList extends StatelessWidget {
  const _ChatsList({
    required this.chatManager,
    required this.selectedChatId,
    required this.onChatTap,
    required this.showSavedMessagesShortcut,
    required this.onSavedMessagesTap,
  });

  final ChatManager chatManager;
  final int? selectedChatId;
  final ValueChanged<int> onChatTap;
  final bool showSavedMessagesShortcut;
  final VoidCallback onSavedMessagesTap;

  @override
  Widget build(BuildContext context) {
    final chats = chatManager.chats
        .where((chat) => chat.kind != ChatKind.savedMessages)
        .toList();
    final activeList = chatManager.activeChatList;

    if (chats.isEmpty && !showSavedMessagesShortcut) {
      final emptyLabel = switch (activeList) {
        ChatListArchive() => 'Архив пуст',
        ChatListFolder() => 'В папке нет чатов',
        _ => 'Загрузка чатов...',
      };
      return Center(child: Text(emptyLabel));
    }

    final itemCount = chats.length + (showSavedMessagesShortcut ? 1 : 0);

    return ListView.separated(
      itemCount: itemCount,
      separatorBuilder: (context, index) {
        if (showSavedMessagesShortcut && index == 0) {
          return const Divider(height: 1);
        }
        return const Divider(height: 1, indent: 72);
      },
      itemBuilder: (context, index) {
        if (showSavedMessagesShortcut && index == 0) {
          return SavedMessagesShortcut(onTap: onSavedMessagesTap);
        }

        final chatIndex = showSavedMessagesShortcut ? index - 1 : index;
        final chat = chats[chatIndex];
        final selected = chat.id == selectedChatId;

        return ChatListDismissible(
          chat: chat,
          activeList: activeList,
          onArchiveToggle: () => _toggleArchive(chatManager, chat.id),
          child: ChatListTile(
            chat: chat,
            selected: selected,
            activeList: activeList,
            onTap: () => onChatTap(chat.id),
            onPinToggle: () => _togglePin(chatManager, chat, activeList),
            onArchiveToggle: () => _toggleArchive(chatManager, chat.id),
            onToggleUnread: () => _toggleUnread(chatManager, chat),
            onClearHistory: chat.canBeDeletedOnlyForSelf
                ? () => chatManager.clearChatHistory(chat.id)
                : null,
            onDeleteChat: () => chatManager.deleteChat(chat.id),
            onDeleteForAll: chat.canBeDeletedForAllUsers
                ? () => chatManager.deleteChatForAll(chat.id)
                : null,
          ),
        );
      },
    );
  }

  void _togglePin(ChatManager chatManager, ChatSummary chat, ChatListKey activeList) {
    if (chat.isPinnedIn(activeList)) {
      chatManager.unpinChat(chat.id);
    } else {
      chatManager.pinChat(chat.id);
    }
  }

  void _toggleArchive(ChatManager chatManager, int chatId) {
    if (chatManager.isArchiveList) {
      chatManager.unarchiveChat(chatId);
    } else {
      chatManager.archiveChat(chatId);
    }
  }

  void _toggleUnread(ChatManager chatManager, ChatSummary chat) {
    chatManager.toggleMarkedAsUnread(
      chat.id,
      isMarkedAsUnread: !chat.isMarkedAsUnread,
    );
  }
}
