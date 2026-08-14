import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/chat/chat_manager.dart';

/// Диалог выбора чата для пересылки сообщений.
class ForwardMessagesDialog extends StatelessWidget {
  const ForwardMessagesDialog({
    super.key,
    required this.messageCount,
  });

  final int messageCount;

  static Future<int?> show(BuildContext context, {required int messageCount}) {
    return showDialog<int>(
      context: context,
      builder: (_) => ForwardMessagesDialog(messageCount: messageCount),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chats = context.watch<ChatManager>().chats;

    return AlertDialog(
      title: Text('Переслать ($messageCount)'),
      content: SizedBox(
        width: 360,
        height: 420,
        child: chats.isEmpty
            ? const Center(child: Text('Нет доступных чатов'))
            : ListView.builder(
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        chat.title.isNotEmpty ? chat.title[0].toUpperCase() : '?',
                      ),
                    ),
                    title: Text(chat.title),
                    onTap: () => Navigator.pop(context, chat.id),
                  );
                },
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

/// Опции пересылки.
class ForwardOptionsDialog extends StatelessWidget {
  const ForwardOptionsDialog({super.key});

  static Future<({bool withoutAuthor, bool removeCaption})?> show(
    BuildContext context,
  ) {
    return showDialog<({bool withoutAuthor, bool removeCaption})>(
      context: context,
      builder: (_) => const ForwardOptionsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    var withoutAuthor = false;
    var removeCaption = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Параметры пересылки'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Без указания автора'),
                value: withoutAuthor,
                onChanged: (value) {
                  setState(() => withoutAuthor = value ?? false);
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Убрать подпись'),
                value: removeCaption,
                onChanged: (value) {
                  setState(() => removeCaption = value ?? false);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                (withoutAuthor: withoutAuthor, removeCaption: removeCaption),
              ),
              child: const Text('Переслать'),
            ),
          ],
        );
      },
    );
  }
}
