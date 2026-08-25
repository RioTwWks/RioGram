import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyStateWidget показывает заголовок и иконку', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TelegramTheme.build(brightness: Brightness.light),
        home: const Scaffold(
          body: EmptyStateWidget(
            icon: Icons.chat_bubble_outline,
            title: 'Нет чатов',
            subtitle: 'Начните переписку',
          ),
        ),
      ),
    );

    expect(find.text('Нет чатов'), findsOneWidget);
    expect(find.text('Начните переписку'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
  });
}
