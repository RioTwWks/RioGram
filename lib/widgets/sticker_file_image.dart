import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/tdlib/tdlib_client.dart';

/// Превью стикера/GIF по file_id TDLib с автозагрузкой.
class StickerFileImage extends StatefulWidget {
  const StickerFileImage({
    super.key,
    required this.fileId,
    this.width = 72,
    this.height = 72,
    this.emoji = '🙂',
    this.fit = BoxFit.contain,
  });

  final int fileId;
  final double width;
  final double height;
  final String emoji;
  final BoxFit fit;

  @override
  State<StickerFileImage> createState() => _StickerFileImageState();
}

class _StickerFileImageState extends State<StickerFileImage> {
  StreamSubscription<Map<String, dynamic>>? _subscription;
  String? _localPath;
  var _requested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureDownload());
  }

  @override
  void didUpdateWidget(covariant StickerFileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileId != widget.fileId) {
      _localPath = null;
      _requested = false;
      _ensureDownload();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _ensureDownload() {
    if (_requested || widget.fileId <= 0) {
      return;
    }
    _requested = true;
    final client = context.read<TdlibClient>();
    _subscription ??= client.updates.listen(_handleUpdate);
    client.send({
      '@type': 'downloadFile',
      'file_id': widget.fileId,
      'priority': 16,
      'offset': 0,
      'limit': 0,
      'synchronous': false,
    });
  }

  void _handleUpdate(Map<String, dynamic> update) {
    if (update['@type'] != 'updateFile') {
      return;
    }
    final file = update['file'] as Map<String, dynamic>?;
    if (file == null || file['id'] != widget.fileId) {
      return;
    }
    final local = file['local'] as Map<String, dynamic>?;
    final path = local?['path'] as String?;
    final completed = local?['is_downloading_completed'] as bool? ?? false;
    if (completed && path != null && path.isNotEmpty && mounted) {
      setState(() => _localPath = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _localPath;
    if (path != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Image.file(
          File(path),
          fit: widget.fit,
          errorBuilder: (_, _, _) => _EmojiFallback(emoji: widget.emoji),
        ),
      );
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: _EmojiFallback(emoji: widget.emoji),
    );
  }
}

class _EmojiFallback extends StatelessWidget {
  const _EmojiFallback({required this.emoji});

  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 28),
      ),
    );
  }
}
