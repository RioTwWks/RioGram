import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/chat/chat_manager.dart';
import '../core/search/search_manager.dart';
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
    context.read<SearchManager>().clearNewChatSearch();
    super.deactivate();
  }

  void _onQueryChanged() {
    context.read<SearchManager>().searchForNewChat(_controller.text);
  }

  bool _needsJoin(SearchManager search, ChatManager chatManager, int chatId) {
    if (!search.isPublicDiscoveryChat(chatId)) {
      return false;
    }
    final chat = chatManager.chatById(chatId);
    if (chat == null) {
      return true;
    }
    return !chat.isInList(const ChatListMain());
  }

  Future<void> _openOrJoinChat(ChatSummary chat) async {
    final chatManager = context.read<ChatManager>();
    final search = context.read<SearchManager>();
    if (_needsJoin(search, chatManager, chat.id)) {
      setState(() => _joiningChatId = chat.id);
      try {
        final chatId = await chatManager.joinChat(chat.id);
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
    final search = context.watch<SearchManager>();
    final results = search.newChatSearchIds
        .map((id) => chatManager.chatById(id))
        .whereType<ChatSummary>()
        .toList();
    final userHit = search.newChatUserHit;

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
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Поиск',
                hintText: 'Имя, @username, телефон, канал',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: search.isNewChatSearchLoading
                  ? const Center(child: CircularProgressIndicator())
                  : results.isEmpty && userHit == null
                      ? Center(
                          child: Text(
                            _controller.text.trim().isEmpty
                                ? 'Введите имя или @username'
                                : 'Ничего не найдено',
                          ),
                        )
                      : ListView.separated(
                          itemCount: results.length + (userHit != null ? 1 : 0),
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            if (userHit != null && index == 0) {
                              return ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person_outline),
                                ),
                                title: Text(userHit.displayName),
                                subtitle: Text(
                                  userHit.username != null
                                      ? '@${userHit.username}'
                                      : 'Пользователь',
                                ),
                                onTap: () async {
                                  try {
                                    final chatId = await chatManager
                                        .createPrivateChat(userHit.userId);
                                    if (context.mounted) {
                                      Navigator.pop(context, chatId);
                                    }
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(error.toString())),
                                      );
                                    }
                                  }
                                },
                              );
                            }

                            final chatIndex =
                                userHit != null ? index - 1 : index;
                            final chat = results[chatIndex];
                            final needsJoin =
                                _needsJoin(search, chatManager, chat.id);
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
      return chat.kind == ChatKind.channel
          ? 'Канал · не подписан'
          : 'Группа · не участник';
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
