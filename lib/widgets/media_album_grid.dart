import 'dart:io';

import 'package:flutter/material.dart';

import '../models/chat_models.dart';

/// Сетка фото/видео в альбоме (grouped_id).
class MediaAlbumGrid extends StatelessWidget {
  const MediaAlbumGrid({
    super.key,
    required this.messages,
    this.onItemTap,
  });

  final List<ChatMessage> messages;
  final void Function(ChatMessage message, int index)? onItemTap;

  @override
  Widget build(BuildContext context) {
    final count = messages.length;
    if (count == 1) {
      return _MediaTile(
        message: messages.first,
        onTap: onItemTap == null ? null : () => onItemTap!(messages.first, 0),
      );
    }

    final visibleCount = count > 4 ? 4 : count;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: count == 2 || count == 4 || count > 4 ? 2 : 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: visibleCount,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _MediaTile(
          message: message,
          showOverlay: count > 4 && index == visibleCount - 1,
          overlayText: count > 4 ? '+${count - 4}' : null,
          onTap: onItemTap == null ? null : () => onItemTap!(message, index),
        );
      },
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.message,
    this.onTap,
    this.showOverlay = false,
    this.overlayText,
  });

  final ChatMessage message;
  final VoidCallback? onTap;
  final bool showOverlay;
  final String? overlayText;

  @override
  Widget build(BuildContext context) {
    final path = message.localFilePath ?? message.content.localPath;
    final kind = message.content.kind;

    Widget child;
    if (path != null && kind == MessageKind.photo) {
      child = Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallbackIcon(kind),
      );
    } else if (kind == MessageKind.video || kind == MessageKind.videoNote) {
      child = Stack(
        fit: StackFit.expand,
        children: [
          if (path != null)
            Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallbackIcon(kind),
            )
          else
            _fallbackIcon(kind),
          const Align(
            alignment: Alignment.center,
            child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 36),
          ),
        ],
      );
    } else {
      child = _fallbackIcon(kind);
    }

    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (showOverlay && overlayText != null)
                Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: Text(
                    overlayText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackIcon(MessageKind kind) {
    return ColoredBox(
      color: Colors.black12,
      child: Icon(
        kind == MessageKind.video || kind == MessageKind.videoNote
            ? Icons.videocam_outlined
            : Icons.image_outlined,
        size: 32,
      ),
    );
  }
}
