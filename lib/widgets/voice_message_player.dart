import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/audio_models.dart';
import 'voice_waveform.dart';

/// Воспроизведение голосового сообщения с waveform.
class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({
    super.key,
    required this.filePath,
    required this.voiceInfo,
    this.isOutgoing = false,
  });

  final String filePath;
  final VoiceNoteInfo voiceInfo;
  final bool isOutgoing;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final _player = AudioPlayer();
  var _isPlaying = false;
  var _position = Duration.zero;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    _positionSub = _player.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _position = position);
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

  double get _playbackProgress {
    final total = widget.voiceInfo.durationSeconds;
    if (total <= 0) {
      return 0;
    }
    return (_position.inMilliseconds / (total * 1000)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minWidth = 220.0;

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: 280),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: _togglePlayback,
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VoiceWaveform(
                  heights: widget.voiceInfo.normalizedWaveform,
                  progress: _playbackProgress,
                  activeColor: widget.isOutgoing
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.primary,
                ),
                const SizedBox(height: 4),
                Text(
                  _isPlaying
                      ? _formatDuration(_position)
                      : widget.voiceInfo.durationLabel,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (minutes > 0) {
      return '$minutes:${rest.toString().padLeft(2, '0')}';
    }
    return '0:${rest.toString().padLeft(2, '0')}';
  }
}
