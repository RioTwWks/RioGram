import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/chat/chat_manager.dart';
import '../../models/forum_models.dart';
import '../../widgets/chat_avatar.dart';
import '../../widgets/chat_list_tile.dart';
import 'chat_screen.dart';
import '../../core/navigation/telegram_routes.dart';

/// Список тем форума в супергруппе.
class ForumTopicsScreen extends StatefulWidget {
  const ForumTopicsScreen({
    super.key,
    required this.chatId,
    this.embedded = false,
    this.onTopicSelected,
  });

  final int chatId;
  final bool embedded;
  final void Function(int forumTopicId, String topicName)? onTopicSelected;

  @override
  State<ForumTopicsScreen> createState() => _ForumTopicsScreenState();
}

class _ForumTopicsScreenState extends State<ForumTopicsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatManager>().loadForumTopics(widget.chatId);
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    context.read<ChatManager>().clearForumTopics(widget.chatId);
    super.dispose();
  }

  void _onSearchChanged() {
    context.read<ChatManager>().loadForumTopics(
          widget.chatId,
          query: _searchController.text,
        );
  }

  Future<void> _createTopic() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Новая тема'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 128,
            decoration: const InputDecoration(
              labelText: 'Название темы',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Создать'),
            ),
          ],
        );
      },
    );
    if (name == null || name.trim().isEmpty || !mounted) {
      return;
    }
    context.read<ChatManager>().createForumTopic(widget.chatId, name);
  }

  void _openTopic(ForumTopicSummary topic) {
    final name = topic.displayName;
    if (widget.onTopicSelected != null) {
      widget.onTopicSelected!(topic.forumTopicId, name);
      return;
    }
    TelegramRoutes.push(context, ChatScreen(chatId: widget.chatId, forumTopicId: topic.forumTopicId, forumTopicName: name));
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ChatManager>();
    final chat = manager.chatById(widget.chatId);
    final topics = manager.forumTopicsFor(widget.chatId);
    final isLoading =
        manager.isLoadingForumTopics &&
        manager.loadingForumTopicsForChatId == widget.chatId;

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Поиск тем',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        if (isLoading && topics.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (manager.forumTopicsError != null && topics.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  manager.forumTopicsError!,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: topics.length,
              separatorBuilder: (_, _ignored) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final topic = topics[index];
                return _ForumTopicTile(
                  topic: topic,
                  onTap: () => _openTopic(topic),
                );
              },
            ),
          ),
      ],
    );

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (chat != null) ...[
                  ChatAvatar(
                    title: chat.title,
                    localPath: chat.avatarLocalPath,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chat.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Форум · ${manager.forumTopicsTotalCountFor(widget.chatId)} тем',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
                IconButton(
                  tooltip: 'Новая тема',
                  onPressed: _createTopic,
                  icon: const Icon(Icons.add_comment_outlined),
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(chat?.title ?? 'Форум'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTopic,
        tooltip: 'Новая тема',
        child: const Icon(Icons.add_comment_outlined),
      ),
      body: body,
    );
  }
}

class _ForumTopicTile extends StatelessWidget {
  const _ForumTopicTile({
    required this.topic,
    required this.onTap,
  });

  final ForumTopicSummary topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = topic.lastMessageDate != null
        ? formatChatListTime(topic.lastMessageDate!)
        : null;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: topic.isGeneral
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.secondaryContainer,
        child: Icon(
          topic.isGeneral ? Icons.forum_outlined : Icons.tag,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              topic.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight:
                    topic.unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          if (topic.isPinned) ...[
            Icon(
              Icons.push_pin,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 4),
          ],
          if (topic.isClosed)
            Icon(
              Icons.lock_outline,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          if (time != null) ...[
            const SizedBox(width: 8),
            Text(
              time,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ],
      ),
      subtitle: topic.lastMessagePreview != null
          ? Text(
              topic.lastMessagePreview!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : topic.isGeneral
              ? const Text('Общая тема форума')
              : null,
      trailing: topic.unreadCount > 0
          ? CircleAvatar(
              radius: 12,
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                topic.unreadCount > 99 ? '99+' : '${topic.unreadCount}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
