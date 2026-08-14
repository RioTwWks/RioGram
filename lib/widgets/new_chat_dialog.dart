import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/chat/chat_manager.dart';
import 'chat_avatar.dart';

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

  @override
  Widget build(BuildContext context) {
    final chatManager = context.watch<ChatManager>();
    final results = chatManager.newChatSearchResults;

    return AlertDialog(
      title: const Text('Новый чат'),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                                ? 'Введите имя или username'
                                : 'Ничего не найдено',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.separated(
                          itemCount: results.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final chat = results[index];
                            return ListTile(
                              leading: ChatAvatar(
                                title: chat.title,
                                localPath: chat.avatarLocalPath,
                                radius: 18,
                              ),
                              title: Text(chat.title),
                              subtitle: chat.lastMessage != null
                                  ? Text(
                                      chat.lastMessage!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              onTap: () => Navigator.pop(context, chat.id),
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
}
