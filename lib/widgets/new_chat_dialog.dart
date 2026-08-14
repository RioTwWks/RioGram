import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/chat/chat_manager.dart';
import '../models/chat_models.dart';
import 'chat_avatar.dart';
import 'chat_list_tile.dart';
import 'create_group_dialog.dart';
import 'join_invite_dialog.dart';

/// Диалог поиска чата / контакта для начала переписки.
class NewChatDialog extends StatefulWidget {
  const NewChatDialog({super.key});

  static Future<int?> show(BuildContext context) {
    return showDialog<int>(
      context: context,
      builder: (_) => const NewChatDialog(),
    );
  }

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  final _controller = TextEditingController();
  var _joiningChatId = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onQueryChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    context.read<ChatManager>().clearNewChatSearch();
    super.deactivate();
  }

  void _onQueryChanged() {
    context.read<ChatManager>().searchForNewChat(_controller.text);
  }

  Future<void> _openOrJoinChat(ChatSummary chat) async {
    final manager = context.read<ChatManager>();
    if (manager.newChatSearchNeedsJoin(chat.id)) {
      setState(() => _joiningChatId = chat.id);
      try {
        final chatId = await manager.joinChat(chat.id);
        if (mounted) {
          Navigator.pop(context, chatId);
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
          setState(() => _joiningChatId = 0);
        }
      }
      return;
    }
    Navigator.pop(context, chat.id);
  }

  Future<void> _openCreateDialog(Future<int?> Function(BuildContext) show) async {
    final chatId = await show(context);
    if (chatId != null && mounted) {
      Navigator.pop(context, chatId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatManager = context.watch<ChatManager>();
    final results = chatManager.newChatSearchResults;

    return AlertDialog(
      title: const Text('Новый чат'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.group_add_outlined, size: 18),
                  label: const Text('Группа'),
                  onPressed: () => _openCreateDialog(
                    (ctx) => CreateGroupDialog.show(ctx, isChannel: false),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.campaign_outlined, size: 18),
                  label: const Text('Канал'),
                  onPressed: () => _openCreateDialog(
                    (ctx) => CreateGroupDialog.show(ctx, isChannel: true),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.link, size: 18),
                  label: const Text('По ссылке'),
                  onPressed: () => _openCreateDialog(JoinInviteDialog.show),
                ),
                ActionChip(
                  avatar: const Icon(Icons.groups_outlined, size: 18),
                  label: const Text('Базовая'),
                  onPressed: () =>
                      _openCreateDialog(CreateBasicGroupDialog.show),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Имя, @username или номер',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: chatManager.isNewChatSearchLoading
                  ? const Center(child: CircularProgressIndicator())
                  : results.isEmpty
                      ? Center(
                          child: Text(
                            _controller.text.isEmpty
                                ? 'Введите имя или @username'
                                : 'Ничего не найдено',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.separated(
                          itemCount: results.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final chat = results[index];
                            final needsJoin =
                                chatManager.newChatSearchNeedsJoin(chat.id);
                            final isJoining = _joiningChatId == chat.id;

                            return ListTile(
                              leading: ChatAvatar(
                                title: chat.title,
                                localPath: chat.avatarLocalPath,
                                radius: 18,
                              ),
                              title: Text(chat.title),
                              subtitle: Text(
                                _chatSubtitle(chat, needsJoin),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: isJoining
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : needsJoin
                                      ? FilledButton.tonal(
                                          onPressed: () => _openOrJoinChat(chat),
                                          child: const Text('Вступить'),
                                        )
                                      : Icon(chatKindIcon(chat.kind), size: 20),
                              onTap: isJoining ? null : () => _openOrJoinChat(chat),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
    );
  }

  String _chatSubtitle(ChatSummary chat, bool needsJoin) {
    if (needsJoin) {
      return chat.kind == ChatKind.channel ? 'Канал · не подписан' : 'Группа · не участник';
    }
    if (chat.lastMessage != null) {
      return chat.lastMessage!;
    }
    return switch (chat.kind) {
      ChatKind.channel => 'Канал',
      ChatKind.group => chat.isBasicGroup ? 'Базовая группа' : 'Группа',
      ChatKind.bot => 'Бот',
      _ => 'Чат',
    };
  }
}
