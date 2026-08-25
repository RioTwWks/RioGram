import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/features/anti_recall_store.dart';
import '../core/features/riogram_features_manager.dart';
import '../core/theme/telegram_theme.dart';
import '../models/anti_recall_models.dart';
import '../models/audio_models.dart';
import '../models/chat_models.dart';
import '../models/formatted_text.dart';
import '../models/message_enrichment.dart';
import '../models/sticker_models.dart';
import '../core/location/map_launcher.dart';
import 'audio_message_player.dart';
import 'document_message_body.dart';
import 'file_transfer_progress_bar.dart';
import 'formatted_text_widget.dart';
import 'inline_keyboard_widget.dart';
import 'inline_video_player.dart';
import 'location_message_body.dart';
import 'media_album_grid.dart';
import 'message_bubble_grouping.dart';
import 'message_delivery_icon.dart';
import 'message_reactions_row.dart';
import 'media_hover_preview.dart';
import 'poll_message_body.dart';
import 'riogram_features_widgets.dart';
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
    this.onInlineWebAppTap,
    this.onInlineSwitchTap,
    this.albumMessages,
    this.onMediaTap,
    this.onCancelTransfer,
    this.onCommentsTap,
    this.showComments = false,
    this.showSenderName = false,
    this.activeLiveLocationMessageId,
    this.groupPosition = BubbleGroupPosition.single,
    this.showTail = true,
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
  final void Function(InlineKeyboardButtonModel button)? onInlineWebAppTap;
  final void Function(InlineKeyboardButtonModel button)? onInlineSwitchTap;
  final List<ChatMessage>? albumMessages;
  final void Function(ChatMessage message)? onMediaTap;
  final VoidCallback? onCancelTransfer;
  final VoidCallback? onCommentsTap;
  final bool showComments;
  final bool showSenderName;
  final int? activeLiveLocationMessageId;
  final BubbleGroupPosition groupPosition;
  final bool showTail;

  @override
  Widget build(BuildContext context) {
    if (message.isServiceMessage) {
      return _ServiceMessageBubble(message: message);
    }

    if (message.content.kind == MessageKind.sticker) {
      return _StickerMessageBubble(
        message: message,
        isSelected: isSelected,
        selectionMode: selectionMode,
        showViewCount: showViewCount,
        onTap: onTap,
        onLongPress: onLongPress,
        onReactionTap: onReactionTap,
        onAddReaction: onAddReaction,
      );
    }

    final tg = context.telegramTheme;
    final isOutgoing = message.isOutgoing;
    final alignment =
        isOutgoing ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isOutgoing ? tg.bubbleOutgoing : tg.bubbleIncoming;
    final borderRadius = MessageBubbleGrouping.bubbleBorderRadius(
      isOutgoing: isOutgoing,
      position: groupPosition,
      radiusScale: tg.cornerRadiusScale,
    );
    final hasTail = MessageBubbleGrouping.shouldShowTail(
      position: groupPosition,
      showTail: showTail,
    );
    final topMargin = groupPosition == BubbleGroupPosition.middle ||
            groupPosition == BubbleGroupPosition.last
        ? 2.0
        : 6.0;
    final bottomMargin = groupPosition == BubbleGroupPosition.first ||
            groupPosition == BubbleGroupPosition.middle
        ? 0.0
        : 6.0;
    final senderColor = MessageBubbleGrouping.senderNameColor(
      message.senderUserId,
      tg.accent,
    );

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: EdgeInsets.only(
                left: 8, right: 8, top: topMargin, bottom: bottomMargin),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isOutgoing && hasTail)
                  _BubbleTail(isOutgoing: false, color: bubbleColor),
                Flexible(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? tg.accent.withValues(alpha: 0.25)
                          : bubbleColor,
                      borderRadius: borderRadius,
                    ),
                    child: ClipRRect(
                      borderRadius: borderRadius,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
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
                                  color: tg.accent,
                                ),
                              ),
                            if (message.forwardInfo != null)
                              _ForwardHeader(
                                  info: message.forwardInfo!,
                                  accent: tg.accent),
                            if (message.replyTo != null)
                              _ReplyQuote(
                                reply: message.replyTo!,
                                preview: replyPreview,
                                accent: tg.accent,
                                textSecondary: tg.textSecondary,
                              ),
                            if (showSenderName && message.senderName != null)
                              Text(
                                message.senderName!,
                                style: TextStyle(
                                  fontSize: TelegramFontSizes.chatSubtitle,
                                  fontWeight: FontWeight.w600,
                                  color: senderColor,
                                ),
                              ),
                            if (showSenderName && message.senderName != null)
                              const SizedBox(height: 4),
                            _MessageBody(
                              message: message,
                              albumMessages: albumMessages,
                              onPollVote: onPollVote,
                              onMediaTap: onMediaTap,
                              activeLiveLocationMessageId:
                                  activeLiveLocationMessageId,
                              metaWidget: _BubbleMetaContent(
                                message: message,
                                showViewCount: showViewCount,
                                timeColor: tg.textTime,
                                accent: tg.accent,
                              ),
                            ),
                            if (message.fileTransfer != null &&
                                message.fileTransfer!.isActive)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: FileTransferProgressBar(
                                  transfer: message.fileTransfer!,
                                  onCancel: onCancelTransfer,
                                ),
                              ),
                            if (message.reactions.isNotEmpty ||
                                onAddReaction != null) ...[
                              const SizedBox(height: 6),
                              MessageReactionsRow(
                                reactions: message.reactions,
                                onReactionTap: onReactionTap,
                                onAddReaction: onAddReaction,
                              ),
                            ],
                            if (showComments && onCommentsTap != null) ...[
                              const SizedBox(height: 6),
                              Align(
                                alignment: isOutgoing
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: onCommentsTap,
                                  icon: const Icon(
                                      Icons.chat_bubble_outline, size: 18),
                                  label: Text(message.replyCount > 0
                                      ? '${message.replyCount} коммент.'
                                      : 'Комментарии'),
                                ),
                              ),
                            ],
                            if (message.inlineKeyboard.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              InlineKeyboardWidget(
                                rows: message.inlineKeyboard,
                                onCallbackTap: onInlineButtonTap,
                                onWebAppTap:
                                    onInlineWebAppTap ?? onInlineButtonTap,
                                onSwitchInlineTap: onInlineSwitchTap,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (isOutgoing && hasTail)
                  _BubbleTail(isOutgoing: true, color: bubbleColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleTail extends StatelessWidget {
  const _BubbleTail({required this.isOutgoing, required this.color});
  final bool isOutgoing;
  final Color color;
  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(8, 12),
        painter: _BubbleTailPainter(isOutgoing: isOutgoing, color: color),
      );
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.isOutgoing, required this.color});
  final bool isOutgoing;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (isOutgoing) {
      path.moveTo(0, 0);
      path.cubicTo(size.width * 0.55, size.height * 0.02, size.width * 1.05,
          size.height * 0.38, size.width * 0.92, size.height * 0.62);
      path.cubicTo(size.width * 0.72, size.height * 0.92, size.width * 0.28,
          size.height * 1.02, 0, size.height * 0.58);
      path.cubicTo(size.width * -0.08, size.height * 0.34, size.width * -0.02,
          size.height * 0.12, 0, 0);
    } else {
      path.moveTo(size.width, 0);
      path.cubicTo(size.width * 0.45, size.height * 0.02, size.width * -0.05,
          size.height * 0.38, size.width * 0.08, size.height * 0.62);
      path.cubicTo(size.width * 0.28, size.height * 0.92, size.width * 0.72,
          size.height * 1.02, size.width, size.height * 0.58);
      path.cubicTo(size.width * 1.08, size.height * 0.34, size.width * 1.02,
          size.height * 0.12, size.width, 0);
    }
    path.close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant _BubbleTailPainter o) =>
      o.color != color || o.isOutgoing != isOutgoing;
}

class _BubbleMetaContent extends StatelessWidget {
  const _BubbleMetaContent({
    required this.message,
    required this.showViewCount,
    required this.timeColor,
    required this.accent,
  });
  final ChatMessage message;
  final bool showViewCount;
  final Color timeColor;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final time = DateFormat.Hm().format(message.date);
    final meta = TextStyle(
        fontSize: TelegramFontSizes.bubbleMeta, color: timeColor);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showViewCount && (message.interactionInfo?.viewCount ?? 0) > 0) ...[
          MessageViewCountLabel(viewCount: message.interactionInfo!.viewCount),
          const SizedBox(width: 6),
        ],
        if (message.schedulingInfo != null) ...[
          Icon(Icons.schedule, size: 12, color: timeColor),
          const SizedBox(width: 3),
        ],
        if (message.isEdited) ...[
          Text('изменено', style: meta.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(width: 4),
        ],
        Text(time, style: meta),
        if (message.isOutgoing && message.deliveryStatus != null) ...[
          const SizedBox(width: 3),
          MessageDeliveryIcon(
            status: message.deliveryStatus!,
            size: 12,
            readColor: accent,
            defaultColor: timeColor,
          ),
        ],
      ],
    );
  }
}

WidgetSpan _metaSpacerSpan(Widget meta) => WidgetSpan(
      alignment: PlaceholderAlignment.bottom,
      child: Opacity(opacity: 0, child: meta),
    );

Widget _textWithInlineMeta({
  required String text,
  TextStyle? style,
  required Widget meta,
}) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Text.rich(TextSpan(text: text, style: style, children: [_metaSpacerSpan(meta)])),
      Positioned(right: 0, bottom: 0, child: meta),
    ],
  );
}

Widget _formattedWithInlineMeta({
  required FormattedText formatted,
  TextStyle? style,
  Color? linkColor,
  required Widget meta,
}) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      FormattedTextWidget(
        formatted: formatted,
        style: style,
        linkColor: linkColor,
        trailingSpans: [_metaSpacerSpan(meta)],
      ),
      Positioned(right: 0, bottom: 0, child: meta),
    ],
  );
}

Widget _overlayMeta(Widget body, Widget meta) {
  return Stack(
    clipBehavior: Clip.none,
    children: [body, Positioned(right: 0, bottom: 0, child: meta)],
  );
}


class _ForwardHeader extends StatelessWidget {
  const _ForwardHeader({required this.info, required this.accent});

  final MessageForwardInfo info;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        info.isHiddenOrigin ? 'Переслано' : 'Переслано от ${info.originLabel}',
        style: TextStyle(
          fontSize: TelegramFontSizes.chatSubtitle,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({
    required this.reply,
    this.preview,
    required this.accent,
    required this.textSecondary,
  });

  final MessageReplyInfo reply;
  final String? preview;
  final Color accent;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reply.authorName != null)
            Text(
              reply.authorName!,
              style: TextStyle(
                fontSize: TelegramFontSizes.chatSubtitle,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          Text(
            preview ?? reply.preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: TelegramFontSizes.preview,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({
    required this.message,
    required this.metaWidget,
    this.albumMessages,
    this.onPollVote,
    this.onMediaTap,
    this.activeLiveLocationMessageId,
  });

  final ChatMessage message;
  final Widget metaWidget;
  final List<ChatMessage>? albumMessages;
  final void Function(int optionId)? onPollVote;
  final void Function(ChatMessage message)? onMediaTap;
  final int? activeLiveLocationMessageId;

  @override
  Widget build(BuildContext context) {
    final antiRecall = context.watch<AntiRecallStore>();
    final mediaFeatures = context.watch<RioGramMediaFeaturesManager>();
    final snapshot = mediaFeatures.antiRecallEnabled
        ? antiRecall.snapshotFor(message.chatId, message.id)
        : null;

    Widget body;
    if (albumMessages != null && albumMessages!.length > 1) {
      final caption = _albumCaption(albumMessages!);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaAlbumGrid(
            messages: albumMessages!,
            onItemTap: onMediaTap == null
                ? null
                : (item, _) => onMediaTap!(item),
          ),
          if (caption != null) ...[
            const SizedBox(height: 8),
            _textWithInlineMeta(
              text: caption,
              style: Theme.of(context).textTheme.bodyMedium,
              meta: metaWidget,
            ),
          ],
        ],
      );
      if (caption == null) {
        body = _overlayMeta(body, metaWidget);
      }
    } else {
      body = _buildPrimaryBody(context, snapshot);
    }

    if (snapshot == null) {
      return body;
    }

    final reasonLabel = switch (snapshot.reason) {
      AntiRecallSnapshotReason.deleted => 'Удалённое сообщение (анти-отзыв)',
      AntiRecallSnapshotReason.edited => 'До редактирования',
      AntiRecallSnapshotReason.received => 'Оригинал',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AntiRecallBanner(
          reasonLabel: reasonLabel,
          preview: snapshot.content.preview,
          caption: snapshot.content.caption,
        ),
        body,
      ],
    );
  }

  Widget _buildPrimaryBody(
    BuildContext context,
    AntiRecallSnapshot? snapshot,
  ) {
    final content = message.content;
    final localPath = message.localFilePath ?? content.localPath;

    if (message.isDeleted && snapshot == null) {
      return _textWithInlineMeta(
        text: content.preview,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
        meta: metaWidget,
      );
    }

    if (message.isDeleted && snapshot != null) {
      return _textWithInlineMeta(
        text: snapshot.content.preview,
        style: Theme.of(context).textTheme.bodyMedium,
        meta: metaWidget,
      );
    }

    if (content.kind == MessageKind.poll && content.poll != null) {
      return _overlayMeta(
        PollMessageBody(poll: content.poll!, onVote: onPollVote),
        metaWidget,
      );
    }

    if (content.kind == MessageKind.call && content.callInfo != null) {
      final info = content.callInfo!;
      final icon = info.isVideo ? Icons.videocam : Icons.call;
      final color = info.isMissed || info.isDeclined
          ? Theme.of(context).colorScheme.error
          : Theme.of(context).colorScheme.primary;
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: _textWithInlineMeta(
              text: info.preview(isOutgoing: message.isOutgoing),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
              meta: metaWidget,
            ),
          ),
        ],
      );
    }

    if ((content.kind == MessageKind.location ||
            content.kind == MessageKind.liveLocation) &&
        content.locationInfo != null) {
      final info = content.locationInfo!;
      return _overlayMeta(
        LocationMessageBody(
          preview: info.preview(),
          point: info.point,
          subtitle: info.liveMeta?.periodLabel,
          isLive: info.isLive,
          isExpired: info.isExpired,
          isBroadcasting: activeLiveLocationMessageId == message.id,
          onOpenMap: () => MapLauncher.openLocation(info.point),
        ),
        metaWidget,
      );
    }

    if (content.kind == MessageKind.venue && content.venueInfo != null) {
      final venue = content.venueInfo!.venue;
      return _overlayMeta(
        LocationMessageBody(
          preview: venue.preview(),
          point: venue.location,
          subtitle: venue.address,
          onOpenMap: () => MapLauncher.openLocation(venue.location, label: venue.title),
        ),
        metaWidget,
      );
    }

    if (content.kind == MessageKind.text) {
      final formatted = content.formattedText;
      if (formatted != null && formatted.text.isNotEmpty) {
        return _formattedWithInlineMeta(formatted: formatted, meta: metaWidget);
      }
      return _textWithInlineMeta(
        text: content.preview,
        style: Theme.of(context).textTheme.bodyMedium,
        meta: metaWidget,
      );
    }

    if (content.kind == MessageKind.photo && localPath != null) {
      final mediaFeatures = context.read<RioGramMediaFeaturesManager>();
      final captionWidgets = _captionWidgets(context, content);
      final photoBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaHoverPreview(
            enabled: mediaFeatures.hoverPreviewEnabled,
            localPath: localPath,
            kind: MessageKind.photo,
            previewLabel: content.caption ?? content.preview,
            child: GestureDetector(
              onTap: onMediaTap == null ? null : () => onMediaTap!(message),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(TelegramRadii.mediaPreview),
                child: Image.file(
                  File(localPath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Text(content.preview),
                ),
              ),
            ),
          ),
          ...captionWidgets,
        ],
      );
      return captionWidgets.isEmpty ? _overlayMeta(photoBody, metaWidget) : photoBody;
    }

    if (content.kind == MessageKind.photo && localPath == null) {
      final captionWidgets = _captionWidgets(context, content);
      final placeholderBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MediaPlaceholder(icon: Icons.image_outlined, label: content.preview),
          ...captionWidgets,
        ],
      );
      return captionWidgets.isEmpty
          ? _overlayMeta(placeholderBody, metaWidget)
          : placeholderBody;
    }

    if (content.kind == MessageKind.video) {
      final mediaFeatures = context.read<RioGramMediaFeaturesManager>();
      final captionWidgets = _captionWidgets(context, content);
      final videoBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (localPath != null)
            MediaHoverPreview(
              enabled: mediaFeatures.hoverPreviewEnabled,
              localPath: localPath,
              kind: MessageKind.video,
              previewLabel: content.videoInfo?.durationLabel,
              child: InlineVideoPlayer(
                filePath: localPath,
                durationLabel: content.videoInfo?.durationLabel,
                onOpenFullscreen: onMediaTap == null ? null : () => onMediaTap!(message),
              ),
            )
          else
            _MediaPlaceholder(
              icon: Icons.videocam_outlined,
              label: content.preview,
              durationLabel: content.videoInfo?.durationLabel,
            ),
          ...captionWidgets,
        ],
      );
      return captionWidgets.isEmpty ? _overlayMeta(videoBody, metaWidget) : videoBody;
    }

    if (content.kind == MessageKind.videoNote) {
      return _overlayMeta(
        Align(
          alignment: Alignment.center,
          child: localPath != null
              ? VideoNotePlayer(
                  filePath: localPath,
                  videoInfo: content.videoInfo,
                  onOpenFullscreen: onMediaTap == null ? null : () => onMediaTap!(message),
                )
              : _MediaPlaceholder(
                  icon: Icons.radio_button_checked_outlined,
                  label: content.preview,
                ),
        ),
        metaWidget,
      );
    }

    if (content.kind == MessageKind.voice) {
      final voiceInfo = content.voiceInfo ?? const VoiceNoteInfo(durationSeconds: 0);
      final captionWidgets = _captionWidgets(context, content);
      final voiceBody = Column(
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
          ...captionWidgets,
        ],
      );
      return captionWidgets.isEmpty ? _overlayMeta(voiceBody, metaWidget) : voiceBody;
    }

    if (content.kind == MessageKind.audio) {
      final audioInfo = content.audioInfo ?? const AudioTrackInfo(durationSeconds: 0);
      final captionWidgets = _captionWidgets(context, content);
      final audioBody = Column(
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
          ...captionWidgets,
        ],
      );
      return captionWidgets.isEmpty ? _overlayMeta(audioBody, metaWidget) : audioBody;
    }

    if (content.kind == MessageKind.document) {
      final captionWidgets = _captionWidgets(context, content);
      final documentBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DocumentMessageBody(
            fileName: content.fileName ?? content.preview,
            documentInfo: content.documentInfo,
          ),
          ...captionWidgets,
        ],
      );
      return captionWidgets.isEmpty
          ? _overlayMeta(documentBody, metaWidget)
          : documentBody;
    }

    if (content.kind == MessageKind.animation) {
      final info = content.animationInfo;
      final captionWidgets = _captionWidgets(context, content);
      final animationBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (localPath != null)
            InlineVideoPlayer(
              filePath: localPath,
              durationLabel: info?.animation.durationLabel,
              onOpenFullscreen: onMediaTap == null ? null : () => onMediaTap!(message),
            )
          else
            _MediaPlaceholder(
              icon: Icons.gif_box_outlined,
              label: content.preview,
              durationLabel: info?.animation.durationLabel,
            ),
          ...captionWidgets,
        ],
      );
      return captionWidgets.isEmpty
          ? _overlayMeta(animationBody, metaWidget)
          : animationBody;
    }

    return _textWithInlineMeta(
      text: content.preview,
      style: Theme.of(context).textTheme.bodyMedium,
      meta: metaWidget,
    );
  }

  List<Widget> _captionWidgets(BuildContext context, MessageContent content) {
    if (content.formattedCaption != null) {
      return [
        const SizedBox(height: 8),
        _formattedWithInlineMeta(
          formatted: content.formattedCaption!,
          meta: metaWidget,
        ),
      ];
    }
    if (content.caption != null) {
      return [
        const SizedBox(height: 8),
        _textWithInlineMeta(
          text: content.caption!,
          style: Theme.of(context).textTheme.bodyMedium,
          meta: metaWidget,
        ),
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
        color: context.telegramTheme.elevatedSurface,
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

class _StickerMessageBubble extends StatelessWidget {
  const _StickerMessageBubble({
    required this.message,
    this.isSelected = false,
    this.selectionMode = false,
    this.showViewCount = false,
    this.onTap,
    this.onLongPress,
    this.onReactionTap,
    this.onAddReaction,
  });

  final ChatMessage message;
  final bool isSelected;
  final bool selectionMode;
  final bool showViewCount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(String emoji)? onReactionTap;
  final VoidCallback? onAddReaction;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    final time = DateFormat.Hm().format(message.date);
    final alignment =
        message.isOutgoing ? Alignment.centerRight : Alignment.centerLeft;
    final content = message.content;
    final localPath = message.localFilePath ?? content.localPath;
    final sticker = content.stickerInfo?.sticker;
    final size = _stickerDisplaySize(sticker);

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: isSelected
                ? BoxDecoration(
                    color: tg.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(TelegramRadii.bubble),
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Column(
                crossAxisAlignment: message.isOutgoing
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (selectionMode)
                    Align(
                      alignment: Alignment.topRight,
                      child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: tg.accent,
                      ),
                    ),
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
                  if (message.reactions.isNotEmpty || onAddReaction != null) ...[
                    const SizedBox(height: 4),
                    MessageReactionsRow(
                      reactions: message.reactions,
                      onReactionTap: onReactionTap,
                      onAddReaction: onAddReaction,
                    ),
                  ],
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showViewCount &&
                          (message.interactionInfo?.viewCount ?? 0) > 0) ...[
                        MessageViewCountLabel(
                          viewCount: message.interactionInfo!.viewCount,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: TelegramFontSizes.bubbleMeta,
                          color: tg.textTime,
                        ),
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

  Size _stickerDisplaySize(StickerModel? sticker) {
    if (sticker == null || sticker.width <= 0 || sticker.height <= 0) {
      return const Size(180, 180);
    }
    const maxSide = 180.0;
    final scale = maxSide / math.max(sticker.width, sticker.height);
    return Size(sticker.width * scale, sticker.height * scale);
  }
}

class _ServiceMessageBubble extends StatelessWidget {
  const _ServiceMessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? TelegramColors.serviceMessageBackgroundDark
        : TelegramColors.serviceMessageBackgroundLight;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              message.content.preview,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: TelegramFontSizes.preview,
                color: TelegramColors.dateSeparatorText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

