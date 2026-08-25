import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../core/features/riogram_features_manager.dart';
import '../core/theme/telegram_theme.dart';
import 'video_playback_speed_controls.dart';

/// Inline-воспроизведение видео в пузыре сообщения.
class InlineVideoPlayer extends StatefulWidget {
  const InlineVideoPlayer({
    super.key,
    required this.filePath,
    this.durationLabel,
    this.maxHeight = 240,
    this.onOpenFullscreen,
  });

  final String filePath;
  final String? durationLabel;
  final double maxHeight;
  final VoidCallback? onOpenFullscreen;

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer> {
  VideoPlayerController? _controller;
  var _initialized = false;
  var _hasError = false;
  var _playbackSpeed = 1.0;
  var _speedLoaded = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_speedLoaded) {
      _playbackSpeed =
          context.read<RioGramMediaFeaturesManager>().defaultVideoSpeed;
      _speedLoaded = true;
    }
  }

  @override
  void didUpdateWidget(covariant InlineVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _disposeController();
      _initController();
    }
  }

  Future<void> _initController() async {
    final controller = VideoPlayerController.file(File(widget.filePath));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setPlaybackSpeed(_playbackSpeed);
      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = true;
        _hasError = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _initialized = false;
    _hasError = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !_initialized) {
      return;
    }
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;

    if (_hasError) {
      return _VideoPlaceholder(
        label: widget.durationLabel,
        icon: Icons.videocam_off_outlined,
        surfaceColor: tg.elevatedSurface,
      );
    }

    if (!_initialized || _controller == null) {
      return _VideoPlaceholder(
        label: widget.durationLabel,
        icon: Icons.hourglass_top,
        surfaceColor: tg.elevatedSurface,
      );
    }

    final controller = _controller!;
    final aspect = controller.value.aspectRatio == 0
        ? 16 / 9
        : controller.value.aspectRatio;

    return ClipRRect(
      borderRadius: BorderRadius.circular(TelegramRadii.mediaPreview),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: aspect,
            child: VideoPlayer(controller),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _togglePlayback,
                onDoubleTap: widget.onOpenFullscreen,
                child: AnimatedOpacity(
                  opacity: controller.value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    color: Colors.black26,
                    alignment: Alignment.center,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.durationLabel != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: _DurationBadge(label: widget.durationLabel!),
            ),
          if (widget.onOpenFullscreen != null)
            Positioned(
              right: 4,
              top: 4,
              child: IconButton(
                tooltip: 'На весь экран',
                onPressed: widget.onOpenFullscreen,
                icon: const Icon(Icons.fullscreen, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                ),
              ),
            ),
          Positioned(
            left: 4,
            bottom: 8,
            child: VideoPlaybackSpeedControls(
              controller: controller,
              speed: _playbackSpeed,
              compact: true,
              onSpeedChanged: (value) => setState(() => _playbackSpeed = value),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({
    required this.label,
    required this.icon,
    required this.surfaceColor,
  });

  final String? label;
  final IconData icon;
  final Color surfaceColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(TelegramRadii.mediaPreview),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: 48),
          if (label != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: _DurationBadge(label: label!),
            ),
        ],
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}
