import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/chat/chat_manager.dart';
import '../../core/user/contact_manager.dart';
import '../../core/proxy/proxy_manager.dart';
import '../../core/search/search_manager.dart';
import '../../core/theme/telegram_theme.dart';
import '../../models/chat_models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stories_strip.dart';
import '../../widgets/chat_desktop_shortcuts.dart';
import '../../core/navigation/telegram_routes.dart';
import '../../widgets/mobile_tab_bar.dart';
import '../../widgets/chat_folder_sidebar.dart';
import '../../widgets/chat_list_tile.dart';
import '../../widgets/chat_search_panel.dart';
import '../../widgets/new_chat_dialog.dart';
import '../../widgets/connection_status_indicator.dart';
import '../chat/chat_screen.dart';
import '../chat/forum_topics_screen.dart';
import '../contacts/contacts_screen.dart';
import '../profile/user_profile_screen.dart';
import '../settings/settings_screen.dart';

/// Адаптивный экран чатов: mobile / master-detail / три колонки (desktop).
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  int? _selectedChatId;
  int? _selectedForumTopicId;
  String? _selectedForumTopicName;
  int _mobileTabIndex = 0;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  /// Master-detail с 720px.
  static const _wideBreakpoint = TelegramLayoutBreakpoints.mobile;

  /// Три колонки: папки | чаты | переписка (как Telegram Desktop).
  static const _threeColumnBreakpoint = TelegramLayoutBreakpoints.threeColumn;

  static const _chatListWidth = TelegramLayoutBreakpoints.chatListWidth;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatManager = context.watch<ChatManager>();
    final searchManager = context.watch<SearchManager>();
    final proxy = context.watch<ProxyManager?>();
    final width = MediaQuery.sizeOf(context).width;

    if (width < _wideBreakpoint) {
      return _buildMobileLayout(context, chatManager, searchManager, proxy);
    }
    if (width < _threeColumnBreakpoint) {
      return _wrapDesktopShortcuts(
        context,
        chatManager,
        _buildTwoColumnLayout(context, chatManager, searchManager, proxy),
      );
    }
    return _wrapDesktopShortcuts(
      context,
      chatManager,
      _buildThreeColumnLayout(context, chatManager, searchManager, proxy),
    );
  }

  Widget _wrapDesktopShortcuts(
    BuildContext context,
    ChatManager chatManager,
    Widget child,
  ) {
    return ChatDesktopShortcuts(
      onFocusSearch: _focusSearch,
      onNewChat: () => _openNewChatDialog(context, chatManager),
      onPreviousChat: () => _selectAdjacentChat(context, chatManager, -1),
      onNextChat: () => _selectAdjacentChat(context, chatManager, 1),
      child: child,
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    ChatManager chatManager,
    SearchManager searchManager,
    ProxyManager? proxy,
  ) {
    return Scaffold(
      appBar: _mobileTabIndex == 0
          ? _buildAppBar(context, chatManager, proxy, showBack: false)
          : _mobileTabIndex == 1
              ? AppBar(
                  title: const Text('Контакты'),
                  actions: [
                    IconButton(
                      tooltip: 'Импорт из адресной книги',
                      onPressed: () {
                        final manager = context.read<ContactManager>();
                        manager.importFromPhoneBook().then((result) {
                          if (!context.mounted) {
                            return;
                          }
                          if (result != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Импортировано: ${result.importedCount}',
                                ),
                              ),
                            );
                          } else if (manager.lastError != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(manager.lastError!)),
                            );
                          }
                        });
                      },
                      icon: const Icon(Icons.contact_phone_outlined),
                    ),
                  ],
                )
              : AppBar(title: const Text('Настройки')),
      body: switch (_mobileTabIndex) {
        1 => const ContactsScreen(embedded: true),
        2 => const SettingsScreen(embedded: true),
        _ => _buildChatListPanel(
            context,
            chatManager,
            searchManager,
            showFolderTabs: true,
          ),
      },
      bottomNavigationBar: MobileTabBar(
        selectedIndex: _mobileTabIndex,
        onDestinationSelected: (index) {
          setState(() => _mobileTabIndex = index);
        },
      ),
      floatingActionButton: _mobileTabIndex == 0
          ? FloatingActionButton(
              tooltip: 'Новое сообщение',
              onPressed: () => _openNewChatDialog(context, chatManager),
              child: const Icon(Icons.edit_outlined),
            )
          : null,
    );
  }

  Widget _buildTwoColumnLayout(
    BuildContext context,
    ChatManager chatManager,
    SearchManager searchManager,
    ProxyManager? proxy,
  ) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: _chatListWidth,
            child: Column(
              children: [
                Material(
                  elevation: 1,
                  child: SafeArea(
                    bottom: false,
                    child: _buildChatListHeader(context, chatManager, proxy),
                  ),
                ),
                Expanded(
                  child: _buildChatListPanel(
                    context,
                    chatManager,
                    searchManager,
                    showFolderTabs: true,
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _buildConversationPane(chatManager)),
        ],
      ),
    );
  }

  Widget _buildThreeColumnLayout(
    BuildContext context,
    ChatManager chatManager,
    SearchManager searchManager,
    ProxyManager? proxy,
  ) {
    return Scaffold(
      body: Row(
        children: [
          ChatFolderSidebar(
            activeList: chatManager.activeChatList,
            folders: chatManager.chatFolders,
            onSelected: chatManager.switchChatList,
            onSettings: () => _openSettings(context),
            hasSavedMessages: chatManager.savedMessagesChatId != null,
            onSavedMessages: () {
              final chatId = chatManager.savedMessagesChatId;
              if (chatId != null) {
                _openChat(context, chatManager, chatId);
              }
            },
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: _chatListWidth,
            child: Column(
              children: [
                Material(
                  elevation: 1,
                  child: SafeArea(
                    bottom: false,
                    child: _buildChatListHeader(context, chatManager, proxy),
                  ),
                ),
                Expanded(
                  child: _buildChatListPanel(
                    context,
                    chatManager,
                    searchManager,
                    showFolderTabs: false,
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _buildConversationPane(chatManager)),
        ],
      ),
    );
  }

  Widget _buildChatListHeader(
    BuildContext context,
    ChatManager chatManager,
    ProxyManager? proxy,
  ) {
    return SizedBox(
      height: kToolbarHeight,
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _chatListTitle(chatManager, chatManager.activeChatList),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: ConnectionStatusIndicator(),
          ),
          IconButton(
            tooltip: 'Новый чат (Ctrl+N)',
            onPressed: () => _openNewChatDialog(context, chatManager),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Контакты',
            onPressed: () => _openContacts(context),
            icon: const Icon(Icons.contacts_outlined),
          ),
          IconButton(
            tooltip: 'Настройки',
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildChatListPanel(
    BuildContext context,
    ChatManager chatManager,
    SearchManager searchManager, {
    required bool showFolderTabs,
  }) {
    return Column(
      children: [
        ChatSearchBar(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: searchManager.setGlobalQuery,
          onClear: () {
            _searchController.clear();
            searchManager.clearGlobalSearch();
          },
        ),
        if (searchManager.isGlobalSearchActive)
          SearchFilterChips(
            selected: searchManager.globalFilter,
            onSelected: searchManager.setGlobalFilter,
          ),
        if (!searchManager.isGlobalSearchActive && showFolderTabs) ...[
          ChatListTabs(
            activeList: chatManager.activeChatList,
            folders: chatManager.chatFolders,
            onSelected: chatManager.switchChatList,
          ),
          const Divider(height: 1),
        ],
        if (!searchManager.isGlobalSearchActive)
          const StoriesStrip(),
        if (!searchManager.isGlobalSearchActive)
          const Divider(height: 1),
        Expanded(
          child: searchManager.isGlobalSearchActive
              ? ChatSearchResults(
                  searchManager: searchManager,
                  chatManager: chatManager,
                  onChatTap: (chatId) => _openChat(context, chatManager, chatId),
                  onMessageTap: (chatId, messageId) {
                    chatManager.openChatAtMessage(chatId, messageId);
                    _openChat(context, chatManager, chatId);
                  },
                  onUserTap: (userId) {
                    TelegramRoutes.push(context, UserProfileScreen(userId: userId));
                  },
                )
              : _ChatsList(
                  chatManager: chatManager,
                  selectedChatId: _selectedChatId,
                  showSavedMessagesShortcut:
                      showFolderTabs &&
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

  Widget _buildConversationPane(ChatManager chatManager) {
    if (_selectedChatId == null) {
      return const EmptyStateWidget(
        icon: Icons.chat_bubble_outline,
        title: 'Выберите чат',
        subtitle: 'Выберите чат из списка слева',
      );
    }

    final chat = chatManager.chatById(_selectedChatId!);
    if (chat?.isForumChat == true && _selectedForumTopicId == null) {
      return ForumTopicsScreen(
        key: ValueKey('forum_${_selectedChatId!}'),
        chatId: _selectedChatId!,
        embedded: true,
        onTopicSelected: (forumTopicId, topicName) {
          setState(() {
            _selectedForumTopicId = forumTopicId;
            _selectedForumTopicName = topicName;
          });
          chatManager.openForumTopic(
            _selectedChatId!,
            forumTopicId,
            topicName: topicName,
          );
        },
      );
    }

    if (_selectedForumTopicId != null) {
      return ChatScreen(
        key: ValueKey('forum_topic_${_selectedChatId!}_$_selectedForumTopicId'),
        chatId: _selectedChatId!,
        forumTopicId: _selectedForumTopicId,
        forumTopicName: _selectedForumTopicName,
        closeOnDispose: false,
        onBackToTopics: () {
          setState(() {
            _selectedForumTopicId = null;
            _selectedForumTopicName = null;
          });
          chatManager.closeChat();
          chatManager.loadForumTopics(_selectedChatId!);
        },
      );
    }

    return ChatScreen(
      key: ValueKey(_selectedChatId),
      chatId: _selectedChatId!,
      closeOnDispose: false,
    );
  }

  String _chatListTitle(ChatManager chatManager, ChatListKey list) {
    return switch (list) {
      ChatListArchive() => 'Архив',
      ChatListFolder(:final folderId) => _folderName(chatManager, folderId),
      _ => 'Чаты',
    };
  }

  String _folderName(ChatManager chatManager, int folderId) {
    for (final folder in chatManager.chatFolders) {
      if (folder.id == folderId) {
        return folder.name;
      }
    }
    return 'Папка';
  }

  void _focusSearch() {
    _searchFocusNode.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
  }

  Future<void> _openNewChatDialog(
    BuildContext context,
    ChatManager chatManager,
  ) async {
    final chatId = await NewChatDialog.show(context);
    if (chatId != null && context.mounted) {
      _openChat(context, chatManager, chatId);
    }
  }

  void _selectAdjacentChat(
    BuildContext context,
    ChatManager chatManager,
    int delta,
  ) {
    if (context.read<SearchManager>().isGlobalSearchActive) {
      return;
    }

    final chats = chatManager.navigableChats;
    if (chats.isEmpty) {
      return;
    }

    var index = chats.indexWhere((chat) => chat.id == _selectedChatId);
    if (index < 0) {
      index = delta > 0 ? 0 : chats.length - 1;
    } else {
      index = (index + delta).clamp(0, chats.length - 1);
    }

    _openChat(context, chatManager, chats[index].id);
  }

  void _openChat(BuildContext context, ChatManager chatManager, int chatId) {
    final chat = chatManager.chatById(chatId);
    final isWide =
        MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    if (chat?.isForumChat == true) {
      if (isWide) {
        setState(() {
          _selectedChatId = chatId;
          _selectedForumTopicId = null;
          _selectedForumTopicName = null;
        });
        chatManager.clearForumTopicSelection();
        chatManager.loadForumTopics(chatId);
        return;
      }

      TelegramRoutes.push(context, ForumTopicsScreen(chatId: chatId));
      return;
    }

    if (isWide) {
      setState(() {
        _selectedChatId = chatId;
        _selectedForumTopicId = null;
        _selectedForumTopicName = null;
      });
      chatManager.openChat(chatId);
      return;
    }

    TelegramRoutes.push(context, ChatScreen(chatId: chatId));
  }

  void _openSettings(BuildContext context) {
    TelegramRoutes.push(context, const SettingsScreen());
  }

  void _openContacts(BuildContext context) {
    TelegramRoutes.push(context, const ContactsScreen());
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
      actions: [
        IconButton(
          tooltip: 'Новый чат',
          onPressed: () => _openNewChatDialog(context, chatManager),
          icon: const Icon(Icons.edit_outlined),
        ),
        ..._buildSharedActions(context, chatManager, proxy),
      ],
    );
  }

  List<Widget> _buildSharedActions(
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
      const Padding(
        padding: EdgeInsets.only(right: 4),
        child: Center(child: ConnectionStatusIndicator()),
      ),
      IconButton(
        tooltip: 'Контакты',
        onPressed: () => _openContacts(context),
        icon: const Icon(Icons.contacts_outlined),
      ),
      IconButton(
        tooltip: 'Настройки',
        onPressed: () => _openSettings(context),
        icon: const Icon(Icons.settings_outlined),
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
      return switch (activeList) {
        ChatListArchive() => const EmptyStateWidget(
            icon: Icons.archive_outlined,
            title: 'Архив пуст',
            subtitle: 'Архивированные чаты появятся здесь',
          ),
        ChatListFolder() => const EmptyStateWidget(
            icon: Icons.folder_outlined,
            title: 'В папке нет чатов',
            subtitle: 'Добавьте чаты в эту папку в настройках',
          ),
        _ => const EmptyStateWidget(
            icon: Icons.chat_bubble_outline,
            title: 'Нет чатов',
            subtitle: 'Начните новую переписку',
          ),
      };
    }

    final itemCount = chats.length + (showSavedMessagesShortcut ? 1 : 0);

    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (showSavedMessagesShortcut && index == 0) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SavedMessagesShortcut(onTap: onSavedMessagesTap),
              Divider(
                height: 1,
                thickness: 1,
                color: context.telegramTheme.chatListDivider,
              ),
            ],
          );
        }

        final chatIndex = showSavedMessagesShortcut ? index - 1 : index;
        final chat = chats[chatIndex];
        final selected = chat.id == selectedChatId;
        final isLast = index == itemCount - 1;

        return ChatListDismissible(
          chat: chat,
          activeList: activeList,
          onArchiveToggle: () => _toggleArchive(chatManager, chat.id),
          child: ChatListTile(
            chat: chat,
            selected: selected,
            activeList: activeList,
            showDivider: !isLast,
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

  void _togglePin(
    ChatManager chatManager,
    ChatSummary chat,
    ChatListKey activeList,
  ) {
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
