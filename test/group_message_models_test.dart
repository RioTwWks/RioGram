import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/chat/formatted_text_builder.dart';
import 'package:riogram/core/chat/tdlib_group_message_parser.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:riogram/models/formatted_text.dart';

void main() {
  final resolver = GroupMessageNameResolver(
    userName: (id) => switch (id) {
      1 => 'Алиса',
      2 => 'Боб',
      3 => 'Кэрол',
      _ => '',
    },
    chatTitle: (id) => id == 10 ? 'Команда' : '',
  );

  group('TdlibGroupMessageParser.parseSenderDisplayName', () {
    test('messageSenderUser', () {
      expect(
        TdlibGroupMessageParser.parseSenderDisplayName(
          {'@type': 'messageSenderUser', 'user_id': 1},
          resolver,
        ),
        'Алиса',
      );
    });

    test('messageSenderChat', () {
      expect(
        TdlibGroupMessageParser.parseSenderDisplayName(
          {'@type': 'messageSenderChat', 'chat_id': 10},
          resolver,
        ),
        'Команда',
      );
    });
  });

  group('TdlibGroupMessageParser.parseServiceContent', () {
    test('messageChatAddMembers — приглашение', () {
      final content = TdlibGroupMessageParser.parseServiceContent(
        {
          '@type': 'messageChatAddMembers',
          'member_user_ids': [2],
        },
        resolver,
        senderId: {'@type': 'messageSenderUser', 'user_id': 1},
      );

      expect(content, isNotNull);
      expect(content!.kind, MessageKind.service);
      expect(content.preview, 'Алиса добавил(а) Боб');
      expect(content.serviceUserIds, [2]);
    });

    test('messageChatAddMembers — самостоятельное вступление', () {
      final content = TdlibGroupMessageParser.parseServiceContent(
        {
          '@type': 'messageChatAddMembers',
          'member_user_ids': [1],
        },
        resolver,
        senderId: {'@type': 'messageSenderUser', 'user_id': 1},
      );

      expect(content!.preview, 'Алиса вступил(а) в группу');
    });

    test('messageChatJoinByLink', () {
      final content = TdlibGroupMessageParser.parseServiceContent(
        {'@type': 'messageChatJoinByLink'},
        resolver,
        senderId: {'@type': 'messageSenderUser', 'user_id': 2},
      );

      expect(content!.preview, 'Боб вступил(а) по ссылке-приглашению');
    });

    test('messageChatDeleteMember — выход', () {
      final content = TdlibGroupMessageParser.parseServiceContent(
        {
          '@type': 'messageChatDeleteMember',
          'user_id': 2,
        },
        resolver,
        senderId: {'@type': 'messageSenderUser', 'user_id': 2},
      );

      expect(content!.preview, 'Боб покинул(а) группу');
    });

    test('messageChatDeleteMember — удаление', () {
      final content = TdlibGroupMessageParser.parseServiceContent(
        {
          '@type': 'messageChatDeleteMember',
          'user_id': 2,
        },
        resolver,
        senderId: {'@type': 'messageSenderUser', 'user_id': 1},
      );

      expect(content!.preview, 'Алиса удалил(а) Боб');
    });

    test('messageBasicGroupChatCreate', () {
      final content = TdlibGroupMessageParser.parseServiceContent(
        {
          '@type': 'messageBasicGroupChatCreate',
          'title': 'Друзья',
          'member_user_ids': [1, 2],
        },
        resolver,
      );

      expect(content!.preview, 'Создана группа «Друзья»');
    });

    test('messagePinMessage', () {
      final content = TdlibGroupMessageParser.parseServiceContent(
        {'@type': 'messagePinMessage', 'message_id': 99},
        resolver,
        senderId: {'@type': 'messageSenderUser', 'user_id': 1},
      );

      expect(content!.preview, 'Алиса закрепил(а) сообщение');
    });

    test('не служебный тип возвращает null', () {
      expect(
        TdlibGroupMessageParser.parseServiceContent(
          {'@type': 'messageText', 'text': {'text': 'hi'}},
          resolver,
        ),
        isNull,
      );
    });
  });

  group('FormattedTextBuilder @all / @admins', () {
    test('распознаёт @all как mention entity', () {
      final formatted = FormattedTextBuilder.buildFromComposer('Привет @all!');
      expect(formatted.text, 'Привет @all!');
      expect(
        formatted.entities.any(
          (entity) =>
              entity.kind == TextEntityKind.mention &&
              formatted.text.substring(
                    entity.offset,
                    entity.offset + entity.length,
                  ) ==
                  '@all',
        ),
        isTrue,
      );
    });

    test('распознаёт @admins как mention entity', () {
      final formatted =
          FormattedTextBuilder.buildFromComposer('Внимание @admins');
      expect(
        formatted.entities.any(
          (entity) =>
              entity.kind == TextEntityKind.mention &&
              formatted.text.substring(
                    entity.offset,
                    entity.offset + entity.length,
                  ) ==
                  '@admins',
        ),
        isTrue,
      );
    });
  });

  group('TextEntity mentionName', () {
    test('парсит textEntityTypeMentionName из TDLib', () {
      final formatted = FormattedText.fromTdlib({
        'text': 'Привет @alice',
        'entities': [
          {
            '@type': 'textEntity',
            'offset': 7,
            'length': 6,
            'type': {
              '@type': 'textEntityTypeMentionName',
              'user_id': 1,
            },
          },
        ],
      });

      expect(formatted.entities.single.kind, TextEntityKind.mentionName);
      expect(formatted.entities.single.userId, 1);
    });
  });
}
