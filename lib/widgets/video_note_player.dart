import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/theme/telegram_theme.dart';
import '../models/media_models.dart';

/// Круглое видеосообщение («кружочек») — 240px по умолчанию.
class VideoNotePlayer extends StatefulWidget {
  const VideoNotePlayer({
    super.key,
    required this.filePath,
    this.videoInfo,
    this.size = 240,
    this.onOpenFullscreen,
  });

  final String filePath;
  final MediaVideoInfo? videoInfo;
  final double size;
  final VoidCallback? onOpenFullscreen;

  @override
  State<VideoNotePlayer> createState() => _VideoNotePlayerState();
}

class _VideoNotePlayerState extends State<VideoNotePlayer> {
  VideoPlayerController? _controller;
  var _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant VideoNotePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _controller?.dispose();
      _init();
    }
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.file(File(widget.filePath));
    _controller = controller;
    try {
      await controller.initialize();
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _initialized = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    final controller = _controller;
    if (controller == null || !_initialized) {
      return;
    }
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  double get _diameter {
    if (widget.videoInfo?.videoNoteLength != null &&
        widget.videoInfo!.videoNoteLength > 0) {
      return widget.videoInfo!.videoNoteLength.toDouble().clamp(120.0, 280.0);
    }
    return widget.size;
  }

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    final diameter = _diameter;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_initialized && _controller != null)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              )
            else
              ColoredBox(
                color: tg.elevatedSurface,
                child: Icon(
                  Icons.videocam_outlined,
                  size: 48,
                  color: tg.textSecondary,
                ),
              ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggle,
                onLongPress: widget.onOpenFullscreen,
                child: SizedBox(
                  width: diameter,
                  height: diameter,
                  child: AnimatedOpacity(
                    opacity: _controller?.value.isPlaying == true ? 0 : 0.35,
                    duration: const Duration(milliseconds: 200),
                    child: const ColoredBox(
                      color: Colors.black,
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
