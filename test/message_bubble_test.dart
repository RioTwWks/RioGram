// §9.11.9 regression — MessageBubble (no golden; CI headless).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:riogram/core/features/anti_recall_store.dart';
import 'package:riogram/core/features/riogram_features_manager.dart';
import 'package:riogram/core/theme/telegram_icons.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:riogram/models/formatted_text.dart';
import 'package:riogram/models/message_enrichment.dart';
import 'package:riogram/widgets/date_separator.dart';
import 'package:riogram/widgets/message_bubble.dart';
import 'package:riogram/widgets/message_bubble_grouping.dart';
import 'package:riogram/widgets/message_delivery_icon.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AntiRecallStore()),
        ChangeNotifierProvider(create: (_) => RioGramMediaFeaturesManager()),
      ],
      child: MaterialApp(
        theme: TelegramTheme.build(brightness: Brightness.light),
        home: Scaffold(body: child),
      ),
    );
  }

  group('MessageDeliveryIcon', () {
    testWidgets('delivered shows double gray checkmarks', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageDeliveryIcon(
              status: MessageDeliveryStatus.delivered,
              defaultColor: TelegramColors.textTimeLight,
            ),
          ),
        ),
      );

      expect(find.byIcon(TelegramIcons.deliveryDelivered), findsOneWidget);
      expect(find.byIcon(TelegramIcons.deliverySent), findsNothing);
    });
  });

  group('MessageBubble layout', () {
    testWidgets('embeds time inline in text bubble', (tester) async {
      final message = ChatMessage(
        id: 1,
        chatId: 1,
        date: DateTime(2025, 8, 15, 14, 32),
        isOutgoing: true,
        deliveryStatus: MessageDeliveryStatus.delivered,
        content: const MessageContent(
          kind: MessageKind.text,
          preview: 'Hello world',
        ),
      );

      await tester.pumpWidget(
        wrap(MessageBubble(message: message)),
      );

      expect(find.textContaining('Hello world'), findsOneWidget);
      expect(find.byIcon(TelegramIcons.deliveryDelivered), findsWidgets);
      expect(find.byType(Stack), findsWidgets);
    });

    testWidgets('reply quote uses tinted accent background', (tester) async {
      final message = ChatMessage(
        id: 2,
        chatId: 1,
        date: DateTime(2025, 8, 15, 14, 33),
        isOutgoing: false,
        replyTo: const MessageReplyInfo(
          messageId: 99,
          preview: 'Quoted text',
          authorName: 'Alice',
        ),
        content: const MessageContent(
          kind: MessageKind.text,
          preview: 'Reply body',
        ),
      );

      await tester.pumpWidget(
        wrap(
          MessageBubble(message: message, replyPreview: 'Quoted text'),
        ),
      );

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Quoted text'), findsOneWidget);
      expect(find.textContaining('Reply body'), findsOneWidget);

      final quote = tester.widget<Container>(
        find.ancestor(
          of: find.text('Quoted text'),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = quote.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(5));
      expect(decoration.color, isNotNull);
      expect(decoration.color!.a, closeTo(0.12, 0.01));
    });

    testWidgets('service message renders centered capsule', (tester) async {
      final message = ChatMessage(
        id: 3,
        chatId: 1,
        date: DateTime(2025, 8, 15, 14, 34),
        isOutgoing: false,
        content: const MessageContent(
          kind: MessageKind.service,
          preview: 'Alice joined the group',
        ),
      );

      await tester.pumpWidget(
        wrap(MessageBubble(message: message)),
      );

      expect(find.text('Alice joined the group'), findsOneWidget);
      final capsule = tester.widget<DecoratedBox>(
        find.ancestor(
          of: find.text('Alice joined the group'),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = capsule.decoration as BoxDecoration;
      expect(decoration.color, TelegramColors.serviceMessageBackgroundLight);
    });

    testWidgets('group last shows Bezier tail', (tester) async {
      final message = ChatMessage(id: 4, chatId: 1, date: DateTime(2025, 8, 15, 14, 36), isOutgoing: true, content: const MessageContent(kind: MessageKind.text, preview: 'Tail'));
      await tester.pumpWidget(wrap(MessageBubble(message: message, groupPosition: BubbleGroupPosition.last)));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('grouped border radius', (tester) async {
      final message = ChatMessage(id: 6, chatId: 1, date: DateTime(2025, 8, 15, 14, 38), isOutgoing: true, content: const MessageContent(kind: MessageKind.text, preview: 'R'));
      await tester.pumpWidget(wrap(MessageBubble(message: message, groupPosition: BubbleGroupPosition.first, showTail: false)));
      final expected = MessageBubbleGrouping.bubbleBorderRadius(isOutgoing: true, position: BubbleGroupPosition.first);
      final decorated = tester.widget<DecoratedBox>(find.descendant(of: find.byType(MessageBubble), matching: find.byType(DecoratedBox)).first);
      expect((decorated.decoration as BoxDecoration).borderRadius, expected);
    });
  });

  group('DateSeparator', () {
    testWidgets('uses white text on tinted capsule', (tester) async {
      await tester.pumpWidget(
        wrap(DateSeparator(date: DateTime(2025, 8, 15))),
      );

      final label = DateSeparator.formatDate(DateTime(2025, 8, 15));
      expect(find.text(label), findsOneWidget);
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.color, TelegramColors.dateSeparatorText);
    });
  });
}
