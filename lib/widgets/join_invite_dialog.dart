import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/chat/chat_manager.dart';

/// Вступление в группу/канал по invite-ссылке.
class JoinInviteDialog extends StatefulWidget {
  const JoinInviteDialog({super.key});

  static Future<int?> show(BuildContext context) {
    return showDialog<int>(
      context: context,
      builder: (_) => const JoinInviteDialog(),
    );
  }

  @override
  State<JoinInviteDialog> createState() => _JoinInviteDialogState();
}

class _JoinInviteDialogState extends State<JoinInviteDialog> {
  final _controller = TextEditingController();
  var _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final link = _controller.text.trim();
    if (link.isEmpty || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final chatId =
          await context.read<ChatManager>().joinChatByInviteLink(link);
      if (mounted) {
        Navigator.pop(context, chatId);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Вступить по ссылке'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'https://t.me/+AbCdEf…',
          labelText: 'Invite-ссылка',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Вступить'),
        ),
      ],
    );
  }
}
