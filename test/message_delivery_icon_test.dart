import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/theme/telegram_icons.dart';
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
    testWidgets('sent — одна галочка', (tester) async {
      await tester.pumpWidget(
        wrap(const MessageDeliveryIcon(status: MessageDeliveryStatus.sent)),
      );

      expect(find.byIcon(TelegramIcons.deliverySent), findsOneWidget);
      expect(find.byIcon(TelegramIcons.deliveryDelivered), findsNothing);
    });

    testWidgets('delivered — две серые галочки', (tester) async {
      const gray = Color(0xFF8E8E93);
      await tester.pumpWidget(
        wrap(
          const MessageDeliveryIcon(
            status: MessageDeliveryStatus.delivered,
            defaultColor: gray,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(TelegramIcons.deliveryDelivered));
      expect(icon.color, gray);
    });

    testWidgets('read — две синие галочки', (tester) async {
      const blue = Color(0xFF3390EC);
      await tester.pumpWidget(
        wrap(
          const MessageDeliveryIcon(
            status: MessageDeliveryStatus.read,
            readColor: blue,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(TelegramIcons.deliveryDelivered));
      expect(icon.color, blue);
    });

    testWidgets('sending — часы', (tester) async {
      await tester.pumpWidget(
        wrap(const MessageDeliveryIcon(status: MessageDeliveryStatus.sending)),
      );

      expect(find.byIcon(TelegramIcons.deliverySending), findsOneWidget);
    });

    testWidgets('failed — иконка ошибки', (tester) async {
      await tester.pumpWidget(
        wrap(const MessageDeliveryIcon(status: MessageDeliveryStatus.failed)),
      );

      expect(find.byIcon(TelegramIcons.deliveryFailed), findsOneWidget);
    });
  });
}
