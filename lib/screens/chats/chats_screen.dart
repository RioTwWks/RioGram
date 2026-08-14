import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/chat/chat_manager.dart';
import '../../models/chat_models.dart';
import '../../widgets/chat_list_tile.dart';
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

  static const _wideBreakpoint = 720.0;

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
      appBar: _buildAppBar(context, proxy, showBack: false),
      body: Column(
        children: [
          ChatListTabs(
            activeList: chatManager.activeChatList,
            folders: chatManager.chatFolders,
            onSelected: chatManager.switchChatList,
          ),
          const Divider(height: 1),
          Expanded(
            child: _ChatsList(
              chatManager: chatManager,
              selectedChatId: _selectedChatId,
              onChatTap: (chatId) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(chatId: chatId),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
                    child: _buildToolbar(context, proxy),
                  ),
                ),
                ChatListTabs(
                  activeList: chatManager.activeChatList,
                  folders: chatManager.chatFolders,
                  onSelected: chatManager.switchChatList,
                ),
                const Divider(height: 1),
                Expanded(
                  child: _ChatsList(
                    chatManager: chatManager,
                    selectedChatId: _selectedChatId,
                    onChatTap: (chatId) {
                      setState(() => _selectedChatId = chatId);
                      chatManager.openChat(chatId);
                    },
                  ),
                ),
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

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ProxyManager? proxy, {
    required bool showBack,
  }) {
    return AppBar(
      title: const Text('Чаты'),
      automaticallyImplyLeading: showBack,
      actions: _buildAppBarActions(context, proxy),
    );
  }

  Widget _buildToolbar(BuildContext context, ProxyManager? proxy) {
    return SizedBox(
      height: kToolbarHeight,
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Expanded(
            child: Text('Чаты', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          ),
          ..._buildAppBarActions(context, proxy),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, ProxyManager? proxy) {
    return [
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
  });

  final ChatManager chatManager;
  final int? selectedChatId;
  final ValueChanged<int> onChatTap;

  @override
  Widget build(BuildContext context) {
    final chats = chatManager.chats;
    final activeList = chatManager.activeChatList;

    if (chats.isEmpty) {
      final emptyLabel = switch (activeList) {
        ChatListArchive() => 'Архив пуст',
        ChatListFolder() => 'В папке нет чатов',
        _ => 'Загрузка чатов...',
      };
      return Center(child: Text(emptyLabel));
    }

    return ListView.separated(
      itemCount: chats.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final chat = chats[index];
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
}
