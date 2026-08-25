import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/widgets/date_separator.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  group('DateSeparator.formatDate', () {
    test('возвращает «Сегодня» для текущего дня', () {
      final now = DateTime.now();
      expect(DateSeparator.formatDate(now), 'Сегодня');
    });

    test('возвращает «Вчера» для вчерашнего дня', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(DateSeparator.formatDate(yesterday), 'Вчера');
    });

    test('форматирует дату на русском', () {
      final date = DateTime(2025, 8, 15);
      expect(DateSeparator.formatDate(date), '15 августа');
    });
  });

  group('DateSeparator widget', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        theme: TelegramTheme.build(brightness: Brightness.light),
        home: Scaffold(body: child),
      );
    }

    testWidgets('показывает capsule с текстом даты', (tester) async {
      await tester.pumpWidget(
        wrap(DateSeparator(date: DateTime(2025, 8, 15))),
      );

      expect(find.text('15 августа'), findsOneWidget);

      final text = tester.widget<Text>(find.text('15 августа'));
      expect(text.style?.fontSize, TelegramFontSizes.preview);
      expect(text.style?.fontWeight, FontWeight.w500);

      final decorated = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(DateSeparator),
          matching: find.byType(DecoratedBox),
        ),
      );
      final radius = decorated.decoration as BoxDecoration;
      expect(radius.borderRadius, BorderRadius.circular(12));
    });
  });
}
