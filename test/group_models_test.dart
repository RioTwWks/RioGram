import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/chat/tdlib_chat_parser.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:riogram/models/group_models.dart';

void main() {
  group('PublicChatLinkParser', () {
    test('распознаёт @username', () {
      expect(PublicChatLinkParser.parseUsername('@durov'), 'durov');
    });

    test('распознаёт t.me/username', () {
      expect(
        PublicChatLinkParser.parseUsername('https://t.me/telegram'),
        'telegram',
      );
    });

    test('не путает invite-ссылку с username', () {
      expect(
        PublicChatLinkParser.parseUsername('https://t.me/joinchat/AAAA'),
        isNull,
      );
    });

    test('распознаёт invite-ссылку', () {
      expect(
        PublicChatLinkParser.parseInviteLink('https://t.me/+AbCdEfGhIjK'),
        isNotNull,
      );
    });
  });

  group('ChatTypeInfo / parseChatType', () {
    test('парсит chatTypeBasicGroup с basic_group_id', () {
      final info = TdlibChatParser.parseChatType({
        '@type': 'chatTypeBasicGroup',
        'basic_group_id': 100,
      });

      expect(info.kind, ChatKind.group);
      expect(info.basicGroupId, 100);
      expect(info.isBasicGroup, isTrue);
      expect(info.supergroupId, isNull);
    });

    test('парсит chatTypeSupergroup: группа и канал', () {
      final group = TdlibChatParser.parseChatType({
        '@type': 'chatTypeSupergroup',
        'supergroup_id': 200,
        'is_channel': false,
      });
      expect(group.kind, ChatKind.group);
      expect(group.supergroupId, 200);
      expect(group.isChannel, isFalse);

      final channel = TdlibChatParser.parseChatType({
        '@type': 'chatTypeSupergroup',
        'supergroup_id': 201,
        'is_channel': true,
      });
      expect(channel.kind, ChatKind.channel);
      expect(channel.isChannel, isTrue);
    });

    test('parseChat сохраняет group ids и forum flag', () {
      final chat = TdlibChatParser.parseChat({
        'id': 1,
        'title': 'Forum',
        'type': {
          '@type': 'chatTypeSupergroup',
          'supergroup_id': 42,
          'is_channel': false,
        },
        'view_as_topics': true,
      });

      expect(chat, isNotNull);
      expect(chat!.supergroupId, 42);
      expect(chat.isForum, isTrue);
      expect(chat.isSupergroup, isTrue);
    });
  });
}
