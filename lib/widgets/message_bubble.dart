import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/audio_models.dart';
import '../models/chat_models.dart';
import '../models/formatted_text.dart';
import '../models/message_enrichment.dart';
import '../models/sticker_models.dart';
import 'audio_message_player.dart';
import 'file_transfer_progress_bar.dart';
import 'formatted_text_widget.dart';
import 'inline_keyboard_widget.dart';
import 'inline_video_player.dart';
import 'media_album_grid.dart';
import 'message_delivery_icon.dart';
import 'message_reactions_row.dart';
import 'poll_message_body.dart';
import 'video_note_player.dart';
import 'voice_message_player.dart';

/// Пузырь сообщения в переписке.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.replyPreview,
    this.isSelected = false,
    this.selectionMode = false,
    this.showViewCount = false,
    this.onTap,
    this.onLongPress,
    this.onReactionTap,
    this.onAddReaction,
    this.onPollVote,
    this.onInlineButtonTap,
    this.albumMessages,
    this.onMediaTap,
    this.onCancelTransfer,
  });

  final ChatMessage message;
  final String? replyPreview;
  final bool isSelected;
  final bool selectionMode;
  final bool showViewCount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(String emoji)? onReactionTap;
  final VoidCallback? onAddReaction;
  final void Function(int optionId)? onPollVote;
  final void Function(InlineKeyboardButtonModel button)? onInlineButtonTap;
  final List<ChatMessage>? albumMessages;
  final void Function(ChatMessage message)? onMediaTap;
  final VoidCallback? onCancelTransfer;

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
                  _MessageBody(
                    message: message,
                    albumMessages: albumMessages,
                    onPollVote: onPollVote,
                    onMediaTap: onMediaTap,
                  ),
                  if (message.fileTransfer != null &&
                      message.fileTransfer!.isActive)
                    FileTransferProgressBar(
                      transfer: message.fileTransfer!,
                      onCancel: onCancelTransfer,
                    ),
                  if (message.reactions.isNotEmpty || onAddReaction != null) ...[
                    const SizedBox(height: 8),
                    MessageReactionsRow(
                      reactions: message.reactions,
                      onReactionTap: onReactionTap,
                      onAddReaction: onAddReaction,
                    ),
                  ],
                  if (message.inlineKeyboard.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    InlineKeyboardWidget(
                      rows: message.inlineKeyboard,
                      onCallbackTap: onInlineButtonTap,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showViewCount &&
                          (message.interactionInfo?.viewCount ?? 0) > 0) ...[
                        MessageViewCountLabel(
                          viewCount: message.interactionInfo!.viewCount,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (message.schedulingInfo != null) ...[
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (message.isEdited) ...[
                        Text(
                          'изменено',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        time,
                        style: theme.textTheme.labelSmall,
                      ),
                      if (message.isOutgoing &&
                          message.deliveryStatus != null) ...[
                        const SizedBox(width: 4),
                        MessageDeliveryIcon(status: message.deliveryStatus!),
                      ],
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
  const _MessageBody({
    required this.message,
    this.albumMessages,
    this.onPollVote,
    this.onMediaTap,
  });

  final ChatMessage message;
  final List<ChatMessage>? albumMessages;
  final void Function(int optionId)? onPollVote;
  final void Function(ChatMessage message)? onMediaTap;

  @override
  Widget build(BuildContext context) {
    if (albumMessages != null && albumMessages!.length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaAlbumGrid(
            messages: albumMessages!,
            onItemTap: onMediaTap == null
                ? null
                : (item, _) => onMediaTap!(item),
          ),
          if (_albumCaption(albumMessages!) != null) ...[
            const SizedBox(height: 8),
            Text(_albumCaption(albumMessages!)!),
          ],
        ],
      );
    }

    final content = message.content;
    final localPath = message.localFilePath ?? content.localPath;

    if (message.isDeleted) {
      return Text(
        content.preview,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }

    if (content.kind == MessageKind.poll && content.poll != null) {
      return PollMessageBody(
        poll: content.poll!,
        onVote: onPollVote,
      );
    }

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
          GestureDetector(
            onTap: onMediaTap == null ? null : () => onMediaTap!(message),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(localPath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Text(content.preview),
              ),
            ),
          ),
          ..._captionWidgets(content),
        ],
      );
    }

    if (content.kind == MessageKind.photo && localPath == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MediaPlaceholder(
            icon: Icons.image_outlined,
            label: content.preview,
          ),
          ..._captionWidgets(content),
        ],
      );
    }

    if (content.kind == MessageKind.video) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (localPath != null)
            InlineVideoPlayer(
              filePath: localPath,
              durationLabel: content.videoInfo?.durationLabel,
              onOpenFullscreen:
                  onMediaTap == null ? null : () => onMediaTap!(message),
            )
          else
            _MediaPlaceholder(
              icon: Icons.videocam_outlined,
              label: content.preview,
              durationLabel: content.videoInfo?.durationLabel,
            ),
          ..._captionWidgets(content),
        ],
      );
    }

    if (content.kind == MessageKind.videoNote) {
      return Align(
        alignment: Alignment.center,
        child: localPath != null
            ? VideoNotePlayer(
                filePath: localPath,
                videoInfo: content.videoInfo,
                onOpenFullscreen:
                    onMediaTap == null ? null : () => onMediaTap!(message),
              )
            : _MediaPlaceholder(
                icon: Icons.radio_button_checked_outlined,
                label: content.preview,
              ),
      );
    }

    if (content.kind == MessageKind.voice) {
      final voiceInfo = content.voiceInfo ?? const VoiceNoteInfo(durationSeconds: 0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (localPath != null)
            VoiceMessagePlayer(
              filePath: localPath,
              voiceInfo: voiceInfo,
              isOutgoing: message.isOutgoing,
            )
          else
            Row(
              children: [
                const Icon(Icons.mic_none),
                const SizedBox(width: 8),
                Text('${content.preview} · ${voiceInfo.durationLabel}'),
              ],
            ),
          ..._captionWidgets(content),
        ],
      );
    }

    if (content.kind == MessageKind.audio) {
      final audioInfo = content.audioInfo ?? const AudioTrackInfo(durationSeconds: 0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (localPath != null)
            AudioMessagePlayer(
              filePath: localPath,
              audioInfo: audioInfo,
              coverPath: message.coverLocalPath,
            )
          else
            Row(
              children: [
                const Icon(Icons.music_note_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(audioInfo.displayTitle),
                      if (audioInfo.displayArtist != null)
                        Text(
                          audioInfo.displayArtist!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ..._captionWidgets(content),
        ],
      );
    }

    if (content.kind == MessageKind.document) {
      final docInfo = content.documentInfo;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(content.fileName ?? content.preview),
                    if (docInfo != null && docInfo.fileSize > 0)
                      Text(
                        docInfo.sizeLabel,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          ..._captionWidgets(content),
        ],
      );
    }

    if (content.kind == MessageKind.sticker) {
      final sticker = content.stickerInfo?.sticker;
      final size = _stickerDisplaySize(sticker);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (localPath != null && sticker != null && !sticker.isAnimated)
            SizedBox(
              width: size.width,
              height: size.height,
              child: Image.file(
                File(localPath),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Text(content.preview),
              ),
            )
          else if (localPath != null && sticker != null && sticker.isVideo)
            SizedBox(
              width: size.width,
              height: size.height,
              child: InlineVideoPlayer(
                filePath: localPath,
                maxHeight: size.height,
              ),
            )
          else
            Text(
              content.preview,
              style: const TextStyle(fontSize: 48),
            ),
        ],
      );
    }

    if (content.kind == MessageKind.animation) {
      final info = content.animationInfo;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (localPath != null)
            InlineVideoPlayer(
              filePath: localPath,
              durationLabel: info?.animation.durationLabel,
              onOpenFullscreen:
                  onMediaTap == null ? null : () => onMediaTap!(message),
            )
          else
            _MediaPlaceholder(
              icon: Icons.gif_box_outlined,
              label: content.preview,
              durationLabel: info?.animation.durationLabel,
            ),
          ..._captionWidgets(content),
        ],
      );
    }

    return Text(content.preview);
  }

  Size _stickerDisplaySize(StickerModel? sticker) {
    if (sticker == null || sticker.width <= 0 || sticker.height <= 0) {
      return const Size(180, 180);
    }
    const maxSide = 180.0;
    final scale = maxSide / math.max(sticker.width, sticker.height);
    return Size(sticker.width * scale, sticker.height * scale);
  }

  List<Widget> _captionWidgets(MessageContent content) {
    if (content.formattedCaption != null) {
      return [
        const SizedBox(height: 8),
        FormattedTextWidget(formatted: content.formattedCaption!),
      ];
    }
    if (content.caption != null) {
      return [
        const SizedBox(height: 8),
        Text(content.caption!),
      ];
    }
    return const [];
  }

  String? _albumCaption(List<ChatMessage> messages) {
    for (final item in messages.reversed) {
      final caption = item.content.caption;
      if (caption != null && caption.isNotEmpty) {
        return caption;
      }
    }
    return null;
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({
    required this.icon,
    required this.label,
    this.durationLabel,
  });

  final IconData icon;
  final String label;
  final String? durationLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40),
              const SizedBox(height: 8),
              Text(label),
            ],
          ),
          if (durationLabel != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    durationLabel!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
