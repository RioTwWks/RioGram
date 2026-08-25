import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/core/theme/ui_customization_manager.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:riogram/models/message_enrichment.dart';
import 'package:riogram/widgets/chat_list_tile.dart';
import 'package:riogram/widgets/message_delivery_icon.dart';

void main() {
  group('parseChatPreviewParts', () {
    test('исходящие сообщения показывают статус доставки', () {
      expect(parseChatPreviewParts('x', hasDraft: false, isOutgoing: true, deliveryStatus: MessageDeliveryStatus.read).outgoingStatus, MessageDeliveryStatus.read);
    });
  });

  Widget wrap(Widget child) => ChangeNotifierProvider(
    create: (_) => UiCustomizationManager(),
    child: MaterialApp(theme: TelegramTheme.build(brightness: Brightness.light), home: Scaffold(body: child)),
  );

  testWidgets('pin рядом со временем', (tester) async {
    final chat = ChatSummary(id: 1, title: 'Alice', lastMessage: 't', lastMessageDate: DateTime.now(), positions: const [ChatPositionInfo(list: ChatListMain(), order: 1, isPinned: true)]);
    await tester.pumpWidget(wrap(ChatListTile(chat: chat, selected: false, activeList: const ChatListMain(), onTap: () {})));
    expect(tester.getRect(find.byIcon(Icons.push_pin)).left, greaterThan(tester.getRect(find.text('Alice')).right));
  });

  testWidgets('outgoing checkmarks', (tester) async {
    final chat = ChatSummary(id: 1, title: 'B', lastMessage: 'hi', lastMessageDate: DateTime.now(), lastMessageIsOutgoing: true, lastMessageDeliveryStatus: MessageDeliveryStatus.read);
    await tester.pumpWidget(wrap(ChatListTile(chat: chat, selected: false, activeList: const ChatListMain(), onTap: () {})));
    expect(find.byType(MessageDeliveryIcon), findsOneWidget);
  });

  testWidgets('row height 72', (tester) async {
    final chat = ChatSummary(id: 1, title: 'C', lastMessageDate: DateTime.now());
    await tester.pumpWidget(wrap(ChatListTile(chat: chat, selected: false, activeList: const ChatListMain(), onTap: () {})));
    final boxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
    expect(boxes.any((box) => box.constraints.minHeight == TelegramSpacing.chatListRowHeight), isTrue);
  });

  testWidgets('underline tabs', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: TelegramTheme.build(brightness: Brightness.light), home: Scaffold(body: ChatListTabs(activeList: const ChatListMain(), folders: const [], onSelected: (_) {}))));
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(TelegramUnderlineTab), findsNWidgets(2));
  });
}
