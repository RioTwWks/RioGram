import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/media/media_file_saver.dart';
import '../../models/chat_models.dart';
import '../../models/media_models.dart';
import '../../widgets/inline_video_player.dart';
import '../../widgets/video_note_player.dart';

/// Полноэкранный просмотрщик: чёрный фон, свайп между медиа, pinch-zoom.
class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  final List<MediaViewerItem> items;
  final int initialIndex;

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  MediaViewerItem get _current => widget.items[_currentIndex];

  Future<void> _saveCurrent() async {
    final path = _current.localPath;
    if (path.isEmpty) {
      return;
    }
    final saved = await MediaFileSaver.saveToDownloads(path);
    if (!mounted) {
      return;
    }
    setState(() {
      _statusMessage =
          saved != null ? 'Сохранено: $saved' : 'Не удалось сохранить';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('${_currentIndex + 1} / ${widget.items.length}'),
        actions: [
          IconButton(
            tooltip: 'Сохранить',
            onPressed: _current.hasLocalFile ? _saveCurrent : null,
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_statusMessage != null)
            Material(
              color: Colors.white12,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _statusMessage = null;
                });
              },
              itemBuilder: (context, index) {
                return _MediaPage(item: widget.items[index]);
              },
            ),
          ),
          if (_current.caption != null && _current.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _current.caption!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaPage extends StatefulWidget {
  const _MediaPage({required this.item});

  final MediaViewerItem item;

  @override
  State<_MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<_MediaPage> {
  VideoPlayerController? _videoController;
  var _videoReady = false;

  @override
  void initState() {
    super.initState();
    _maybeInitVideo();
  }

  @override
  void didUpdateWidget(covariant _MediaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.localPath != widget.item.localPath ||
        oldWidget.item.kind != widget.item.kind) {
      _videoController?.dispose();
      _videoController = null;
      _videoReady = false;
      _maybeInitVideo();
    }
  }

  Future<void> _maybeInitVideo() async {
    final kind = widget.item.kind;
    if (kind != MessageKind.video && kind != MessageKind.videoNote) {
      return;
    }
    if (!widget.item.hasLocalFile) {
      return;
    }
    final controller = VideoPlayerController.file(File(widget.item.localPath));
    _videoController = controller;
    try {
      await controller.initialize();
      if (mounted) {
        setState(() => _videoReady = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _videoReady = false);
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    if (!item.hasLocalFile) {
      return const Center(
        child: Text(
          'Файл ещё загружается…',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: switch (item.kind) {
        MessageKind.photo => _ZoomableImage(path: item.localPath),
        MessageKind.video => Center(
            child: _videoReady && _videoController != null
                ? _ZoomableVideo(controller: _videoController!)
                : InlineVideoPlayer(filePath: item.localPath),
          ),
        MessageKind.videoNote => Center(
            child: VideoNotePlayer(
              filePath: item.localPath,
              videoInfo: item.videoInfo,
              size: 240,
            ),
          ),
        _ => Center(
            child: Text(
              item.localPath,
              style: const TextStyle(color: Colors.white54),
            ),
          ),
      },
    );
  }
}

class _ZoomableImage extends StatelessWidget {
  const _ZoomableImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5,
      panEnabled: true,
      scaleEnabled: true,
      clipBehavior: Clip.none,
      child: Center(
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _ZoomableVideo extends StatefulWidget {
  const _ZoomableVideo({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_ZoomableVideo> createState() => _ZoomableVideoState();
}

class _ZoomableVideoState extends State<_ZoomableVideo> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onVideoUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVideoUpdate);
    super.dispose();
  }

  void _onVideoUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isPlaying = controller.value.isPlaying;

    return InteractiveViewer(
      minScale: 1,
      maxScale: isPlaying ? 1 : 3,
      panEnabled: !isPlaying,
      scaleEnabled: !isPlaying,
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
            if (!isPlaying)
              IconButton(
                iconSize: 64,
                color: Colors.white,
                onPressed: () => controller.play(),
                icon: const Icon(Icons.play_circle),
              ),
          ],
        ),
      ),
    );
  }
}
