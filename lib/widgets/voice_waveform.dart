import 'package:flutter/material.dart';

import '../core/theme/telegram_theme.dart';

/// Waveform голосового сообщения (§9.11.7: 5px bars, 2px gap, 34 bars).
class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    super.key,
    required this.heights,
    this.progress = 0,
    this.activeColor,
    this.inactiveColor,
    this.height = 28,
  });

  final List<double> heights;
  final double progress;
  final Color? activeColor;
  final Color? inactiveColor;
  final double height;

  static List<double> resampleBars(List<double> source) {
    const targetCount = TelegramMediaSpacing.waveformBarCount;
    if (source.isEmpty) {
      return List<double>.generate(
        targetCount,
        (index) => 0.25 + 0.5 * ((index % 5) / 4),
        growable: false,
      );
    }
    if (source.length == targetCount) return source;
    final result = List<double>.filled(targetCount, 0);
    for (var i = 0; i < targetCount; i++) {
      final sourceIndex = (i * source.length / targetCount).floor();
      result[i] = source[sourceIndex.clamp(0, source.length - 1)];
    }
    return result;
  }

  static double get intrinsicWidth {
    const count = TelegramMediaSpacing.waveformBarCount;
    return count * TelegramMediaSpacing.waveformBarWidth +
        (count - 1) * TelegramMediaSpacing.waveformBarGap;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = activeColor ?? theme.colorScheme.primary;
    final inactive = inactiveColor ?? theme.colorScheme.onSurfaceVariant;
    final bars = resampleBars(heights);

    return SizedBox(
      height: height,
      width: intrinsicWidth,
      child: CustomPaint(
        painter: _WaveformPainter(
          heights: bars,
          progress: progress,
          activeColor: active,
          inactiveColor: inactive,
        ),
        size: Size(intrinsicWidth, height),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.heights,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<double> heights;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.isEmpty) return;

    final barWidth = TelegramMediaSpacing.waveformBarWidth;
    final gap = TelegramMediaSpacing.waveformBarGap;
    final progressX = size.width * progress.clamp(0.0, 1.0);

    for (var i = 0; i < heights.length; i++) {
      final x = i * (barWidth + gap);
      final barHeight = (heights[i] * size.height).clamp(4.0, size.height);
      final y = (size.height - barHeight) / 2;
      final paint = Paint()
        ..color = x + barWidth <= progressX ? activeColor : inactiveColor
        ..strokeWidth = barWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x + barWidth / 2, y),
        Offset(x + barWidth / 2, y + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.heights != heights ||
        oldDelegate.activeColor != activeColor;
  }
}
