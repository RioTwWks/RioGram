// §9.11.9 regression — MessageInputBar (no golden; CI headless).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/theme/telegram_icons.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/models/formatted_text.dart';
import 'package:riogram/widgets/message_input_bar.dart';

void main() {
  testWidgets('placeholder, reply strip, mic/send toggle', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: TelegramTheme.build(brightness: Brightness.light),
      home: Scaffold(body: MessageInputBar(
        controller: controller,
        onSend: () {},
        onAttach: () {},
        onSchedule: () {},
        onVoiceAction: () {},
        replyDraft: const MessageReplyDraft(messageId: 1, preview: 'Q', authorName: 'A'),
      )),
    ));
    expect(find.text('Сообщение'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.byIcon(TelegramIcons.mic), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'hi');
    await tester.pump();
    expect(find.byIcon(TelegramIcons.send), findsOneWidget);
  });
}
