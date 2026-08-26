// §9.11.9 regression — ChatListTile (no golden; CI headless).

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

  group('formatGroupChatPreviewText', () {
    test('добавляет префикс отправителя в группах', () {
      expect(
        formatGroupChatPreviewText(
          text: 'Привет',
          senderName: 'Alice',
          showPrefix: true,
        ),
        'Alice: Привет',
      );
      expect(
        formatGroupChatPreviewText(
          text: 'Привет',
          senderName: 'Alice',
          showPrefix: false,
        ),
        'Привет',
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
      final now = DateTime.now();
      final todayAt = DateTime(now.year, now.month, now.day, 14, 32);
      final chat = ChatSummary(
        id: 1,
        title: 'Alice',
        lastMessage: '📷 Фото',
        lastMessageDate: todayAt,
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
        greaterThan(tester.getRect(find.text('Alice')).center.dx),
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

    testWidgets('typing preview в accent цвете', (tester) async {
      final chat = ChatSummary(
        id: 5,
        title: 'Group',
        lastMessage: 'old',
        lastMessageDate: DateTime.now(),
        kind: ChatKind.group,
      );

      await tester.pumpWidget(
        wrap(
          ChatListTile(
            chat: chat,
            selected: false,
            activeList: const ChatListMain(),
            chatActionPreview: 'печатает…',
            onTap: () {},
          ),
        ),
      );

      expect(find.text('печатает…'), findsOneWidget);
      expect(find.text('old'), findsNothing);

      final preview = tester.widget<Text>(find.text('печатает…'));
      final tg = TelegramTheme.build(brightness: Brightness.light)
          .extension<TelegramThemeData>()!;
      expect(preview.style?.color, tg.accent);
    });

    testWidgets('group sender prefix в preview', (tester) async {
      final chat = ChatSummary(
        id: 6,
        title: 'Team',
        lastMessage: 'Привет',
        lastMessageDate: DateTime.now(),
        kind: ChatKind.group,
        lastMessageSenderName: 'Bob',
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

      expect(find.text('Bob: Привет'), findsOneWidget);
    });

    testWidgets('badge на строке preview', (tester) async {
      final chat = ChatSummary(
        id: 7,
        title: 'Unread',
        lastMessage: 'msg',
        lastMessageDate: DateTime.now(),
        unreadCount: 2,
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

      final titleBox = tester.getRect(find.text('Unread'));
      final badgeBox = tester.getRect(find.text('2'));
      expect(badgeBox.top, greaterThan(titleBox.bottom));
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

    testWidgets('selected accent 8%', (tester) async {
      final chat = ChatSummary(id: 3, title: 'Sel', lastMessageDate: DateTime.now());
      await tester.pumpWidget(wrap(ChatListTile(chat: chat, selected: true, activeList: const ChatListMain(), onTap: () {})));
      final material = tester.widget<Material>(find.descendant(of: find.byType(ChatListTile), matching: find.byType(Material)).first);
      expect(material.color?.a, closeTo(0.08, 0.01));
    });

    testWidgets('horizontal padding 12px', (tester) async {
      final chat = ChatSummary(id: 4, title: 'Pad', lastMessageDate: DateTime.now());
      await tester.pumpWidget(wrap(ChatListTile(chat: chat, selected: false, activeList: const ChatListMain(), onTap: () {})));
      expect(find.descendant(of: find.byType(ConstrainedBox), matching: find.byWidgetPredicate((w) => w is Padding && w.padding == const EdgeInsets.all(TelegramSpacing.chatListHorizontalPadding))), findsOneWidget);
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
