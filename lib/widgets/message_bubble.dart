import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/chat_models.dart';
import '../models/formatted_text.dart';
import 'formatted_text_widget.dart';

/// Пузырь сообщения в переписке.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.replyPreview,
    this.isSelected = false,
    this.selectionMode = false,
    this.onTap,
    this.onLongPress,
  });

  final ChatMessage message;
  final String? replyPreview;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

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
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Card(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.25)
                : color,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectionMode)
                    Align(
                      alignment: Alignment.topRight,
                      child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  if (message.forwardInfo != null)
                    _ForwardHeader(info: message.forwardInfo!),
                  if (message.replyTo != null)
                    _ReplyQuote(
                      reply: message.replyTo!,
                      preview: replyPreview,
                    ),
                  _MessageBody(message: message),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.schedulingInfo != null) ...[
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        time,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForwardHeader extends StatelessWidget {
  const _ForwardHeader({required this.info});

  final MessageForwardInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        info.isHiddenOrigin ? 'Переслано' : 'Переслано от ${info.originLabel}',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({
    required this.reply,
    this.preview,
  });

  final MessageReplyInfo reply;
  final String? preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
        color: theme.colorScheme.surface.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reply.authorName != null)
            Text(
              reply.authorName!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          Text(
            preview ?? reply.preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
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
      final formatted = content.formattedText;
      if (formatted != null && formatted.text.isNotEmpty) {
        return FormattedTextWidget(formatted: formatted);
      }
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
          if (content.formattedCaption != null) ...[
            const SizedBox(height: 8),
            FormattedTextWidget(formatted: content.formattedCaption!),
          ] else if (content.caption != null) ...[
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
          if (content.formattedCaption != null)
            FormattedTextWidget(formatted: content.formattedCaption!)
          else if (content.caption != null)
            Text(content.caption!),
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
