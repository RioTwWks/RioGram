import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/chat_models.dart';

/// Пузырь сообщения в переписке.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateFormat.Hm().format(message.date);
    final alignment =
        message.isOutgoing ? Alignment.centerRight : Alignment.centerLeft;
    final color = message.isOutgoing
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        child: Card(
          color: color,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MessageBody(message: message),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final content = message.content;
    final localPath = message.localFilePath ?? content.localPath;

    if (content.kind == MessageKind.text) {
      return Text(content.preview);
    }

    if (content.kind == MessageKind.photo && localPath != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(localPath),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Text(content.preview),
            ),
          ),
          if (content.caption != null) ...[
            const SizedBox(height: 8),
            Text(content.caption!),
          ],
        ],
      );
    }

    if (content.kind == MessageKind.video) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle_outline),
              const SizedBox(width: 8),
              Expanded(child: Text(localPath != null ? 'Видео' : content.preview)),
            ],
          ),
          if (content.caption != null) Text(content.caption!),
        ],
      );
    }

    if (content.kind == MessageKind.document) {
      return Row(
        children: [
          const Icon(Icons.attach_file),
          const SizedBox(width: 8),
          Expanded(
            child: Text(content.fileName ?? content.preview),
          ),
        ],
      );
    }

    return Text(content.preview);
  }
}
