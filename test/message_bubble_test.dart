// §9.11.9 regression — MessageBubble (no golden; CI headless).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:riogram/core/features/anti_recall_store.dart';
import 'package:riogram/core/features/riogram_features_manager.dart';
import 'package:riogram/core/plugins/plugin_manager.dart';
import 'package:riogram/core/theme/telegram_icons.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:riogram/models/formatted_text.dart';
import 'package:riogram/models/link_preview_models.dart';
import 'package:riogram/models/message_enrichment.dart';
import 'package:riogram/widgets/date_separator.dart';
import 'package:riogram/widgets/link_preview_widget.dart';
import 'package:riogram/widgets/message_bubble.dart';
import 'package:riogram/widgets/message_bubble_grouping.dart';
import 'package:riogram/widgets/message_delivery_icon.dart';
import 'package:riogram/widgets/scroll_to_bottom_button.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AntiRecallStore()),
        ChangeNotifierProvider(create: (_) => RioGramMediaFeaturesManager()),
        ChangeNotifierProvider(create: (_) => PluginManager()),
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

    testWidgets('service message renders centered gray text without capsule',
        (tester) async {
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
      expect(find.byType(DecoratedBox), findsNothing);

      final text = tester.widget<Text>(find.text('Alice joined the group'));
      expect(text.textAlign, TextAlign.center);
      expect(text.style?.color, TelegramColors.textSecondaryLight);
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

    testWidgets('link preview card shows domain', (tester) async {
      final message = ChatMessage(
        id: 7,
        chatId: 1,
        date: DateTime(2025, 8, 15, 14, 40),
        isOutgoing: false,
        content: MessageContent(
          kind: MessageKind.text,
          preview: 'Check https://example.com',
          formattedText: const FormattedText(
            text: 'Check https://example.com',
            entities: [
              TextEntity(
                offset: 6,
                length: 19,
                kind: TextEntityKind.url,
              ),
            ],
          ),
          linkPreview: const LinkPreviewInfo(
            url: 'https://example.com',
            displayUrl: 'example.com',
            title: 'Example Domain',
          ),
        ),
      );

      await tester.pumpWidget(wrap(MessageBubble(message: message)));

      expect(find.byType(LinkPreviewWidget), findsOneWidget);
      expect(find.text('example.com'), findsOneWidget);
      expect(find.text('Example Domain'), findsOneWidget);
    });

    testWidgets('meta row uses baseline alignment', (tester) async {
      final message = ChatMessage(
        id: 8,
        chatId: 1,
        date: DateTime(2025, 8, 15, 14, 41),
        isOutgoing: true,
        deliveryStatus: MessageDeliveryStatus.read,
        content: const MessageContent(
          kind: MessageKind.text,
          preview: 'Meta',
        ),
      );

      await tester.pumpWidget(wrap(MessageBubble(message: message)));

      final row = tester.widgetList<Row>(
        find.descendant(
          of: find.byType(MessageBubble),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Row &&
                w.crossAxisAlignment == CrossAxisAlignment.baseline &&
                w.textBaseline == TextBaseline.alphabetic,
          ),
        ),
      ).first;
      expect(row.children.length, greaterThan(1));
    });
  });

  group('ScrollToBottomButton', () {
    testWidgets('uses stadium capsule shape', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TelegramTheme.build(brightness: Brightness.light),
          home: Scaffold(
            body: ScrollToBottomButton(
              newMessageCount: 3,
              onPressed: () {},
            ),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(ScrollToBottomButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.shape, isA<StadiumBorder>());
      expect(find.text('3 новых сообщений'), findsOneWidget);
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
