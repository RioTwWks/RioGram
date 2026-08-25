import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/chat_models.dart';
import 'inline_video_player.dart';

/// Превью фото/видео при наведении курсора (десктоп).
class MediaHoverPreview extends StatefulWidget {
  const MediaHoverPreview({
    super.key,
    required this.child,
    required this.enabled,
    this.localPath,
    this.kind,
    this.previewLabel,
  });

  final Widget child;
  final bool enabled;
  final String? localPath;
  final MessageKind? kind;
  final String? previewLabel;

  @override
  State<MediaHoverPreview> createState() => _MediaHoverPreviewState();
}

class _MediaHoverPreviewState extends State<MediaHoverPreview> {
  OverlayEntry? _overlayEntry;
  var _isHovering = false;

  bool get _supportsHover {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux =>
        true,
      _ => false,
    };
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay(BuildContext context, Offset globalPosition) {
    final path = widget.localPath;
    final kind = widget.kind;
    if (path == null || path.isEmpty || kind == null) {
      return;
    }
    if (!File(path).existsSync()) {
      return;
    }

    _removeOverlay();
    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    const previewWidth = 320.0;
    const previewHeight = 240.0;
    var left = globalPosition.dx + 16;
    var top = globalPosition.dy - previewHeight - 12;
    if (left + previewWidth > screenSize.width - 16) {
      left = globalPosition.dx - previewWidth - 16;
    }
    if (top < 16) {
      top = globalPosition.dy + 16;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        width: previewWidth,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: _HoverPreviewBody(
            path: path,
            kind: kind,
            label: widget.previewLabel,
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !_supportsHover) {
      return widget.child;
    }

    return MouseRegion(
      onEnter: (event) {
        _isHovering = true;
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          if (!mounted || !_isHovering) {
            return;
          }
          _showOverlay(context, event.position);
        });
      },
      onExit: (_) {
        _isHovering = false;
        _removeOverlay();
      },
      onHover: (event) {
        if (_overlayEntry != null) {
          _removeOverlay();
          _showOverlay(context, event.position);
        }
      },
      child: widget.child,
    );
  }
}

class _HoverPreviewBody extends StatelessWidget {
  const _HoverPreviewBody({
    required this.path,
    required this.kind,
    this.label,
  });

  final String path;
  final MessageKind kind;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 220,
          child: switch (kind) {
            MessageKind.photo ||
            MessageKind.sticker ||
            MessageKind.animation =>
              Image.file(File(path), fit: BoxFit.cover),
            MessageKind.video || MessageKind.videoNote => InlineVideoPlayer(
                filePath: path,
                durationLabel: label,
                maxHeight: 220,
              ),
            _ => Center(
                child: Text(
                  label ?? path.split('/').last,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          },
        ),
        if (label != null && label!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              label!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
