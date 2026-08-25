import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/models/message_enrichment.dart';
import 'package:riogram/widgets/message_delivery_icon.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: TelegramTheme.build(brightness: Brightness.light),
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('MessageDeliveryIcon', () {
    testWidgets('sending — access_time', (tester) async {
      await tester.pumpWidget(
        wrap(MessageDeliveryIcon(status: MessageDeliveryStatus.sending)),
      );
      expect(find.byIcon(Icons.access_time), findsOneWidget);
    });

    testWidgets('failed — error_outline', (tester) async {
      await tester.pumpWidget(
        wrap(MessageDeliveryIcon(status: MessageDeliveryStatus.failed)),
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('sent — check', (tester) async {
      await tester.pumpWidget(
        wrap(MessageDeliveryIcon(status: MessageDeliveryStatus.sent)),
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('read — done_all с primary accent', (tester) async {
      await tester.pumpWidget(
        wrap(MessageDeliveryIcon(status: MessageDeliveryStatus.read)),
      );

      expect(find.byIcon(Icons.done_all), findsOneWidget);

      final icon = tester.widget<Icon>(find.byIcon(Icons.done_all));
      expect(icon.color, TelegramColors.accent);
    });

    testWidgets('поддерживает кастомный size', (tester) async {
      await tester.pumpWidget(
        wrap(
          MessageDeliveryIcon(
            status: MessageDeliveryStatus.sent,
            size: 11,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(icon.size, 11);
    });
  });

  group('MessageViewCountLabel', () {
    testWidgets('скрывается при viewCount <= 0', (tester) async {
      await tester.pumpWidget(
        wrap(const MessageViewCountLabel(viewCount: 0)),
      );
      expect(find.byType(MessageViewCountLabel), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    });

    testWidgets('форматирует тысячи', (tester) async {
      await tester.pumpWidget(
        wrap(const MessageViewCountLabel(viewCount: 1500)),
      );
      expect(find.text('1.5K'), findsOneWidget);
    });
  });
}
