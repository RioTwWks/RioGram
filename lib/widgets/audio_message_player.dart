import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/audio_models.dart';

/// Плеер аудиофайла / музыки с обложкой и метаданными.
class AudioMessagePlayer extends StatefulWidget {
  const AudioMessagePlayer({
    super.key,
    required this.filePath,
    required this.audioInfo,
    this.coverPath,
  });

  final String filePath;
  final AudioTrackInfo audioInfo;
  final String? coverPath;

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  final _player = AudioPlayer();
  var _isPlaying = false;
  var _position = Duration.zero;
  var _duration = Duration.zero;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.audioInfo.durationSeconds);
    _positionSub = _player.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });
    _durationSub = _player.onDurationChanged.listen((duration) {
      if (mounted && duration.inSeconds > 0) {
        setState(() => _duration = duration);
      }
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
      return;
    }
    await _player.play(DeviceFileSource(widget.filePath));
    setState(() => _isPlaying = true);
  }

  double get _progress {
    if (_duration.inMilliseconds <= 0) {
      return 0;
    }
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverPath = widget.coverPath;

    return SizedBox(
      width: 280,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: coverPath != null
                ? Image.file(
                    File(coverPath),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _coverFallback(theme),
                  )
                : _coverFallback(theme),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.audioInfo.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                if (widget.audioInfo.displayArtist != null)
                  Text(
                    widget.audioInfo.displayArtist!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _togglePlayback,
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LinearProgressIndicator(value: _progress),
                          const SizedBox(height: 4),
                          Text(
                            '${_format(_position)} / ${_format(_duration)}',
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverFallback(ThemeData theme) {
    return Container(
      width: 56,
      height: 56,
      color: theme.colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.music_note),
    );
  }

  String _format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
