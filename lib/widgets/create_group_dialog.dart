import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/chat/chat_manager.dart';

/// Создание супергруппы или канала.
class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({
    super.key,
    required this.isChannel,
  });

  final bool isChannel;

  static Future<int?> show(
    BuildContext context, {
    required bool isChannel,
  }) {
    return showDialog<int>(
      context: context,
      builder: (_) => CreateGroupDialog(isChannel: isChannel),
    );
  }

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  var _isForum = false;
  var _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final chatId = await context.read<ChatManager>().createSupergroupChat(
            title: title,
            isChannel: widget.isChannel,
            description: _descriptionController.text,
            isForum: _isForum && !widget.isChannel,
          );
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
    final label = widget.isChannel ? 'канал' : 'группу';

    return AlertDialog(
      title: Text('Новая ${widget.isChannel ? 'канал' : 'группа'}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Название $label',
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Описание (необязательно)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            if (!widget.isChannel) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Форум с темами'),
                value: _isForum,
                onChanged: (value) => setState(() => _isForum = value),
              ),
            ],
          ],
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
              : const Text('Создать'),
        ),
      ],
    );
  }
}

/// Создание базовой группы (legacy).
class CreateBasicGroupDialog extends StatefulWidget {
  const CreateBasicGroupDialog({super.key});

  static Future<int?> show(BuildContext context) {
    return showDialog<int>(
      context: context,
      builder: (_) => const CreateBasicGroupDialog(),
    );
  }

  @override
  State<CreateBasicGroupDialog> createState() => _CreateBasicGroupDialogState();
}

class _CreateBasicGroupDialogState extends State<CreateBasicGroupDialog> {
  final _titleController = TextEditingController();
  var _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final chatId = await context.read<ChatManager>().createBasicGroupChat(
            title: title,
          );
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
      title: const Text('Базовая группа'),
      content: TextField(
        controller: _titleController,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Название группы',
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
              : const Text('Создать'),
        ),
      ],
    );
  }
}
