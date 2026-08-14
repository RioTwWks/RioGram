import 'package:flutter/material.dart';

/// Waveform голосового сообщения.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = activeColor ?? theme.colorScheme.primary;
    final inactive = inactiveColor ?? theme.colorScheme.onSurfaceVariant;

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _WaveformPainter(
          heights: heights,
          progress: progress,
          activeColor: active,
          inactiveColor: inactive,
        ),
        size: Size.infinite,
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
    if (heights.isEmpty) {
      return;
    }

    final barWidth = size.width / heights.length;
    final gap = barWidth * 0.25;
    final drawWidth = barWidth - gap;
    final progressX = size.width * progress.clamp(0.0, 1.0);

    for (var i = 0; i < heights.length; i++) {
      final x = i * barWidth + gap / 2;
      final barHeight = (heights[i] * size.height).clamp(4.0, size.height);
      final y = (size.height - barHeight) / 2;
      final paint = Paint()
        ..color = x + drawWidth <= progressX ? activeColor : inactiveColor
        ..strokeWidth = drawWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x + drawWidth / 2, y),
        Offset(x + drawWidth / 2, y + barHeight),
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
