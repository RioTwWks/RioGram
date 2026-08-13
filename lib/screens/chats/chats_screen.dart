import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/chat/chat_manager.dart';
import '../../models/chat_models.dart';
import '../../widgets/chat_avatar.dart';
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
      body: _ChatsList(
        chats: chatManager.chats,
        selectedChatId: _selectedChatId,
        onChatTap: (chatId) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChatScreen(chatId: chatId),
            ),
          );
        },
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
                Expanded(
                  child: _ChatsList(
                    chats: chatManager.chats,
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
    required this.chats,
    required this.selectedChatId,
    required this.onChatTap,
  });

  final List<ChatSummary> chats;
  final int? selectedChatId;
  final ValueChanged<int> onChatTap;

  @override
  Widget build(BuildContext context) {
    if (chats.isEmpty) {
      return const Center(child: Text('Загрузка чатов...'));
    }

    return ListView.separated(
      itemCount: chats.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final chat = chats[index];
        final selected = chat.id == selectedChatId;
        final subtitle = chat.lastMessage;
        final time = chat.lastMessageDate != null
            ? DateFormat('dd.MM HH:mm').format(chat.lastMessageDate!)
            : null;

        return ListTile(
          selected: selected,
          leading: ChatAvatar(
            title: chat.title,
            localPath: chat.avatarLocalPath,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  chat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (time != null) ...[
                const SizedBox(width: 8),
                Text(time, style: Theme.of(context).textTheme.labelSmall),
              ],
            ],
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: chat.unreadCount > 0
              ? CircleAvatar(
                  radius: 10,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    '${chat.unreadCount}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                )
              : null,
          onTap: () => onChatTap(chat.id),
        );
      },
    );
  }
}
