import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/telegram_theme.dart';

class DateSeparator extends StatelessWidget {
  const DateSeparator({super.key, required this.date});
  final DateTime date;

  static String formatDate(DateTime date) {
    final now = DateTime.now();
    if (_sameDay(date, now)) return 'Сегодня';
    final y = now.subtract(const Duration(days: 1));
    if (_sameDay(date, y)) return 'Вчера';
    return DateFormat('d MMMM', 'ru').format(date);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tg.dateSeparatorBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              formatDate(date),
              style: const TextStyle(
                fontSize: TelegramFontSizes.preview,
                color: TelegramColors.dateSeparatorText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
