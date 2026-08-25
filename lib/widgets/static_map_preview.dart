import 'package:flutter/material.dart';

import '../core/theme/telegram_theme.dart';
import '../models/location_models.dart';

/// Статическое превью карты для геолокации (скругление [TelegramRadii.mediaPreview]).
class StaticMapPreview extends StatelessWidget {
  const StaticMapPreview({
    super.key,
    required this.point,
    this.width = 280,
    this.height = 140,
  });

  final LocationPoint point;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    final lat = point.latitude;
    final lon = point.longitude;

    final mapUrl = 'https://staticmap.openstreetmap.de/staticmap.php'
        '?center=$lat,$lon&zoom=14&size=${width.toInt()}x${height.toInt()}'
        '&markers=$lat,$lon,red';

    return ClipRRect(
      borderRadius: BorderRadius.circular(TelegramRadii.mediaPreview),
      child: SizedBox(
        width: width,
        height: height,
        child: Image.network(
          mapUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) {
              return child;
            }
            return _MapPlaceholder(
              width: width,
              height: height,
              accent: tg.accent,
              showProgress: true,
            );
          },
          errorBuilder: (_, _, _) => _MapPlaceholder(
            width: width,
            height: height,
            accent: tg.accent,
          ),
        ),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({
    required this.width,
    required this.height,
    required this.accent,
    this.showProgress = false,
  });

  final double width;
  final double height;
  final Color accent;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _MapGridPainter(accent: accent),
      child: Center(
        child: showProgress
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accent,
                ),
              )
            : Icon(Icons.location_on, color: accent, size: 32),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  _MapGridPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFE8E4DA);
    canvas.drawRect(Offset.zero & size, bg);

    final road = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height * 0.4),
      Offset(size.width, size.height * 0.55),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.45, size.height),
      road,
    );

    final park = Paint()..color = const Color(0xFFC8E6C9);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.55,
        size.height * 0.1,
        size.width * 0.35,
        size.height * 0.35,
      ),
      park,
    );

    final pin = Paint()..color = accent;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 6, pin);
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      12,
      pin..color = accent.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
