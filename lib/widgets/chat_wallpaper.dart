import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/telegram_theme.dart';

/// Фон переписки в стиле классического Telegram: сплошной цвет + doodle-паттерн.
///
/// На mobile — полупрозрачный тайловый узор поверх [TelegramThemeData.chatBackground]
/// (как Android `#E6EBEE`). На desktop — белый/нейтральный фон с очень лёгким узором
/// ([TelegramThemeData.isDesktopChatBackground]).
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    final brightness = Theme.of(context).brightness;

    return CustomPaint(
      painter: _ChatDoodlePainter(
        backgroundColor: tg.chatBackground,
        patternColor: _patternColor(brightness),
        patternOpacity: tg.isDesktopChatBackground ? 0.035 : 0.08,
        tileSize: tg.isDesktopChatBackground ? 160 : 120,
      ),
      size: Size.infinite,
    );
  }

  static Color _patternColor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);
  }
}

/// Программный doodle-тайл: простые геометрические фигуры как в TG Android.
class _ChatDoodlePainter extends CustomPainter {
  _ChatDoodlePainter({
    required this.backgroundColor,
    required this.patternColor,
    required this.patternOpacity,
    required this.tileSize,
  });

  final Color backgroundColor;
  final Color patternColor;
  final double patternOpacity;
  final double tileSize;

  static const List<void Function(Canvas canvas, Paint paint)> _doodles = [
    _drawCircle,
    _drawTriangle,
    _drawPlus,
    _drawArc,
    _drawDotCluster,
    _drawWave,
    _drawDiamond,
    _drawRing,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = backgroundColor,
    );

    final paint = Paint()
      ..color = patternColor.withValues(alpha: patternOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = patternColor.withValues(alpha: patternOpacity * 0.65)
      ..style = PaintingStyle.fill;

    final cols = (size.width / tileSize).ceil() + 1;
    final rows = (size.height / tileSize).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final origin = Offset(col * tileSize, row * tileSize);
        final seed = row * 1000 + col;
        final doodleIndex = seed % _doodles.length;
        final offset = Offset(
          (seed * 17 % 40) - 20,
          (seed * 31 % 40) - 20,
        );
        final scale = 0.85 + (seed % 5) * 0.05;

        canvas.save();
        canvas.translate(origin.dx + tileSize / 2 + offset.dx,
            origin.dy + tileSize / 2 + offset.dy);
        canvas.scale(scale);
        _doodles[doodleIndex](canvas, paint);
        if (doodleIndex.isEven) {
          _doodles[(doodleIndex + 3) % _doodles.length](canvas, fillPaint);
        }
        canvas.restore();
      }
    }
  }

  static void _drawCircle(Canvas canvas, Paint paint) {
    canvas.drawCircle(Offset.zero, 10, paint);
  }

  static void _drawTriangle(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(0, -12)
      ..lineTo(10, 8)
      ..lineTo(-10, 8)
      ..close();
    canvas.drawPath(path, paint);
  }

  static void _drawPlus(Canvas canvas, Paint paint) {
    canvas.drawLine(const Offset(-8, 0), const Offset(8, 0), paint);
    canvas.drawLine(const Offset(0, -8), const Offset(0, 8), paint);
  }

  static void _drawArc(Canvas canvas, Paint paint) {
    canvas.drawArc(
      const Rect.fromLTWH(-12, -12, 24, 24),
      math.pi * 0.15,
      math.pi * 1.2,
      false,
      paint,
    );
  }

  static void _drawDotCluster(Canvas canvas, Paint paint) {
    final dotPaint = paint..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(-6, -4), 2, dotPaint);
    canvas.drawCircle(const Offset(5, -2), 2, dotPaint);
    canvas.drawCircle(const Offset(0, 6), 2, dotPaint);
    paint.style = PaintingStyle.stroke;
  }

  static void _drawWave(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(-12, 2)
      ..quadraticBezierTo(-4, -8, 4, 2)
      ..quadraticBezierTo(10, 10, 12, 0);
    canvas.drawPath(path, paint);
  }

  static void _drawDiamond(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(0, -10)
      ..lineTo(8, 0)
      ..lineTo(0, 10)
      ..lineTo(-8, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  static void _drawRing(Canvas canvas, Paint paint) {
    canvas.drawCircle(Offset.zero, 10, paint);
    final inner = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = paint.strokeWidth;
    canvas.drawCircle(Offset.zero, 5, inner);
  }

  @override
  bool shouldRepaint(covariant _ChatDoodlePainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.patternColor != patternColor ||
        oldDelegate.patternOpacity != patternOpacity ||
        oldDelegate.tileSize != tileSize;
  }
}
