import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Доступные скорости воспроизведения видео.
const List<double> kVideoPlaybackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

/// Панель управления скоростью воспроизведения видео.
class VideoPlaybackSpeedControls extends StatelessWidget {
  const VideoPlaybackSpeedControls({
    super.key,
    required this.controller,
    required this.speed,
    required this.onSpeedChanged,
    this.compact = false,
  });

  final VideoPlayerController controller;
  final double speed;
  final ValueChanged<double> onSpeedChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return PopupMenuButton<double>(
        tooltip: 'Скорость',
        initialValue: speed,
        onSelected: (value) {
          controller.setPlaybackSpeed(value);
          onSpeedChanged(value);
        },
        itemBuilder: (context) => kVideoPlaybackSpeeds
            .map(
              (value) => PopupMenuItem<double>(
                value: value,
                child: Text(
                  '${value}x',
                  style: speed == value ? const TextStyle(fontWeight: FontWeight.bold) : null,
                ),
              ),
            )
            .toList(),
        child: _SpeedChip(label: '${speed}x'),
      );
    }

    return Wrap(
      spacing: 6,
      children: kVideoPlaybackSpeeds.map((value) {
        final selected = (speed - value).abs() < 0.01;
        return ChoiceChip(
          label: Text('${value}x'),
          selected: selected,
          onSelected: (_) {
            controller.setPlaybackSpeed(value);
            onSpeedChanged(value);
          },
        );
      }).toList(),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}
