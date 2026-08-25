import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:riogram/widgets/message_bubble_grouping.dart';

void main() {
  group('MessageBubbleGrouping', () {
    test('groups adjacent messages from same sender', () {
      final messages = [
        _msg(id: 1, senderId: 10, outgoing: false, hour: 10),
        _msg(id: 2, senderId: 10, outgoing: false, hour: 10, minute: 1),
        _msg(id: 3, senderId: 11, outgoing: false, hour: 10, minute: 2),
      ];

      final entries = MessageBubbleGrouping.buildListEntries(
        messages: messages,
        showSenderNamesInGroups: true,
      );

      final messageEntries = entries
          .whereType<ChatListMessageEntry>()
          .toList();
      expect(messageEntries.length, 3);
      expect(messageEntries[0].groupPosition, BubbleGroupPosition.first);
      expect(messageEntries[1].groupPosition, BubbleGroupPosition.last);
      expect(messageEntries[2].groupPosition, BubbleGroupPosition.single);
      expect(messageEntries[0].showSenderName, isTrue);
      expect(messageEntries[1].showSenderName, isFalse);
    });

    test('buildListEntries inserts date separators', () {
      final messages = [
        _msg(id: 1, day: 14),
        _msg(id: 2, day: 15),
      ];

      final entries = MessageBubbleGrouping.buildListEntries(
        messages: messages,
        showSenderNamesInGroups: false,
      );

      expect(entries.whereType<ChatListDateEntry>().length, 2);
    });
  });
}

ChatMessage _msg({
  required int id,
  int? senderId,
  bool outgoing = false,
  int hour = 12,
  int minute = 0,
  int day = 15,
}) {
  return ChatMessage(
    id: id,
    chatId: 1,
    date: DateTime(2025, 8, day, hour, minute),
    isOutgoing: outgoing,
    senderUserId: senderId,
    senderName: senderId != null ? 'User $senderId' : null,
    content: MessageContent(
      kind: MessageKind.text,
      preview: 'text $id',
    ),
  );
}
