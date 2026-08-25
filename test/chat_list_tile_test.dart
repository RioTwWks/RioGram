import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:riogram/core/theme/telegram_icons.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/core/theme/ui_customization_manager.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:riogram/models/message_enrichment.dart';
import 'package:riogram/widgets/chat_list_tile.dart';
import 'package:riogram/widgets/message_delivery_icon.dart';

void main() {
  group('formatChatListTime', () {
    test('возвращает HH:mm для сегодняшних сообщений', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 14, 32);
      expect(formatChatListTime(today), '14:32');
    });

    test('возвращает «вчера» без uppercase', () {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1, 10, 0);
      expect(formatChatListTime(yesterday), 'вчера');
      expect(formatChatListTime(yesterday), isNot(contains('ВЧЕРА')));
    });
  });

  group('parseChatPreviewParts', () {
    test('распознаёт фото и микрофон', () {
      final photo = parseChatPreviewParts('📷 Фото', hasDraft: false);
      expect(photo.icon, TelegramIcons.photo);
      expect(photo.text, 'Фото');

      final voice = parseChatPreviewParts('🎤 Голосовое', hasDraft: false);
      expect(voice.icon, TelegramIcons.mic);
      expect(voice.text, 'Голосовое');
    });

    test('черновик показывает иконку редактирования', () {
      final draft = parseChatPreviewParts('Черновик: привет', hasDraft: true);
      expect(draft.icon, TelegramIcons.draft);
      expect(draft.text, 'привет');
      expect(draft.isDraft, isTrue);
    });

    test('исходящие сообщения показывают статус доставки', () {
      expect(
        parseChatPreviewParts(
          'x',
          hasDraft: false,
          isOutgoing: true,
          deliveryStatus: MessageDeliveryStatus.read,
        ).outgoingStatus,
        MessageDeliveryStatus.read,
      );
    });
  });

  group('ChatListTile', () {
    Widget wrap(Widget child) {
      return ChangeNotifierProvider(
        create: (_) => UiCustomizationManager(),
        child: MaterialApp(
          theme: TelegramTheme.build(brightness: Brightness.light),
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('показывает имя, preview, время и badge', (tester) async {
      final chat = ChatSummary(
        id: 1,
        title: 'Alice',
        lastMessage: '📷 Фото',
        lastMessageDate: DateTime(2026, 8, 25, 14, 32),
        unreadCount: 3,
        positions: const [
          ChatPositionInfo(
            list: ChatListMain(),
            order: 1,
            isPinned: true,
          ),
        ],
      );

      await tester.pumpWidget(
        wrap(
          ChatListTile(
            chat: chat,
            selected: false,
            activeList: const ChatListMain(),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Фото'), findsOneWidget);
      expect(find.text('14:32'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(TelegramIcons.pin), findsOneWidget);
      expect(find.byIcon(TelegramIcons.photo), findsOneWidget);
    });

    testWidgets('pin рядом со временем', (tester) async {
      final chat = ChatSummary(
        id: 1,
        title: 'Alice',
        lastMessage: 't',
        lastMessageDate: DateTime.now(),
        positions: const [
          ChatPositionInfo(
            list: ChatListMain(),
            order: 1,
            isPinned: true,
          ),
        ],
      );

      await tester.pumpWidget(
        wrap(
          ChatListTile(
            chat: chat,
            selected: false,
            activeList: const ChatListMain(),
            onTap: () {},
          ),
        ),
      );

      expect(
        tester.getRect(find.byIcon(TelegramIcons.pin)).left,
        greaterThan(tester.getRect(find.text('Alice')).right),
      );
    });

    testWidgets('outgoing checkmarks', (tester) async {
      final chat = ChatSummary(
        id: 1,
        title: 'B',
        lastMessage: 'hi',
        lastMessageDate: DateTime.now(),
        lastMessageIsOutgoing: true,
        lastMessageDeliveryStatus: MessageDeliveryStatus.read,
      );

      await tester.pumpWidget(
        wrap(
          ChatListTile(
            chat: chat,
            selected: false,
            activeList: const ChatListMain(),
            onTap: () {},
          ),
        ),
      );

      expect(find.byType(MessageDeliveryIcon), findsOneWidget);
    });

    testWidgets('row height 72', (tester) async {
      final chat = ChatSummary(
        id: 1,
        title: 'C',
        lastMessageDate: DateTime.now(),
      );

      await tester.pumpWidget(
        wrap(
          ChatListTile(
            chat: chat,
            selected: false,
            activeList: const ChatListMain(),
            onTap: () {},
          ),
        ),
      );

      final boxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      expect(
        boxes.any(
          (box) => box.constraints.minHeight == TelegramSpacing.chatListRowHeight,
        ),
        isTrue,
      );
    });

    testWidgets('mute снижает opacity preview и показывает колокольчик', (tester) async {
      final chat = ChatSummary(
        id: 2,
        title: 'Bob',
        lastMessage: 'Текст',
        lastMessageDate: DateTime.now(),
        isMuted: true,
      );

      await tester.pumpWidget(
        wrap(
          ChatListTile(
            chat: chat,
            selected: false,
            activeList: const ChatListMain(),
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(TelegramIcons.mute), findsOneWidget);

      final preview = tester.widget<Text>(find.text('Текст'));
      final color = preview.style?.color;
      expect(color, isNotNull);
      expect(color!.a, lessThan(1.0));
    });
  });

  testWidgets('underline tabs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TelegramTheme.build(brightness: Brightness.light),
        home: Scaffold(
          body: ChatListTabs(
            activeList: const ChatListMain(),
            folders: const [],
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(TelegramFlatChip), findsNothing);
    expect(find.byType(TelegramUnderlineTab), findsNWidgets(2));
  });
}
