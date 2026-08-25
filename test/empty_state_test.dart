import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyStateWidget SVG illustration', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: TelegramTheme.build(brightness: Brightness.light),
      home: const Scaffold(body: EmptyStateWidget(
        illustration: EmptyStateIllustration.noChats,
        title: 'Нет чатов',
        subtitle: 'Начните переписку',
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Нет чатов'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
