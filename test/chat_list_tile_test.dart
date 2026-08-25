import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:riogram/widgets/chat_list_tile.dart';

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
      expect(photo.icon, Icons.photo_camera_outlined);
      expect(photo.text, 'Фото');

      final voice = parseChatPreviewParts('🎤 Голосовое', hasDraft: false);
      expect(voice.icon, Icons.mic);
      expect(voice.text, 'Голосовое');
    });

    test('черновик показывает иконку редактирования', () {
      final draft = parseChatPreviewParts('Черновик: привет', hasDraft: true);
      expect(draft.icon, Icons.edit_outlined);
      expect(draft.text, 'привет');
      expect(draft.isDraft, isTrue);
    });
  });

  group('ChatListTile', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        theme: TelegramTheme.build(brightness: Brightness.light),
        home: Scaffold(body: child),
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
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
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

      expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);

      final preview = tester.widget<Text>(find.text('Текст'));
      final color = preview.style?.color;
      expect(color, isNotNull);
      expect(color!.a, lessThan(1.0));
    });
  });
}
