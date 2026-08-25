import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/search/tdlib_search_parser.dart';
import 'package:riogram/models/search_models.dart';

void main() {
  group('SearchMessageFilterKind', () {
    test('toTdlib maps media filter', () {
      expect(
        SearchMessageFilterKind.media.toTdlib()['@type'],
        'searchMessagesFilterPhotoAndVideo',
      );
    });

    test('toTdlib maps links filter', () {
      expect(
        SearchMessageFilterKind.links.toTdlib()['@type'],
        'searchMessagesFilterUrl',
      );
    });
  });

  group('TdlibSearchParser', () {
    test('parseFoundMessages reads hits', () {
      final hits = TdlibSearchParser.parseFoundMessages({
        '@type': 'foundMessages',
        'total_count': 1,
        'next_offset': 'abc',
        'messages': [
          {
            '@type': 'message',
            'id': 10,
            'chat_id': 5,
            'date': 1_700_000_000,
            'content': {
              '@type': 'messageText',
              'text': {
                '@type': 'formattedText',
                'text': 'hello',
                'entities': [],
              },
            },
          },
        ],
      });

      expect(hits, hasLength(1));
      expect(hits.first.chatId, 5);
      expect(hits.first.messageId, 10);
      expect(hits.first.preview, contains('hello'));
    });

    test('parseFoundChatMessages reads chat-local hits', () {
      final hits = TdlibSearchParser.parseFoundChatMessages(
        {
          '@type': 'foundChatMessages',
          'total_count': 1,
          'next_from_message_id': 42,
          'messages': [
            {
              '@type': 'message',
              'id': 99,
              'chat_id': 7,
              'date': 1_700_000_100,
              'content': {
                '@type': 'messageText',
                'text': {
                  '@type': 'formattedText',
                  'text': 'local',
                  'entities': [],
                },
              },
            },
          ],
        },
        chatId: 7,
        chatTitle: 'Test',
      );

      expect(hits.first.messageId, 99);
      expect(hits.first.chatTitle, 'Test');
      expect(
        TdlibSearchParser.parseFoundChatMessagesNextFromId({
          '@type': 'foundChatMessages',
          'next_from_message_id': 42,
        }),
        42,
      );
    });

    test('parsePhoneNumber accepts international format', () {
      expect(
        TdlibSearchParser.parsePhoneNumber('+7 900 123 45 67'),
        '+79001234567',
      );
      expect(TdlibSearchParser.parsePhoneNumber('abc'), isNull);
    });

    test('parseInviteToken extracts joinchat token', () {
      expect(
        TdlibSearchParser.parseInviteToken('https://t.me/joinchat/AAAA-BBBB'),
        'AAAA-BBBB',
      );
    });

    test('parseUserHit maps user', () {
      final hit = TdlibSearchParser.parseUserHit({
        '@type': 'user',
        'id': 3,
        'first_name': 'Anna',
        'last_name': '',
        'usernames': {
          '@type': 'usernames',
          'active_usernames': ['anna'],
          'disabled_usernames': [],
          'editable_username': 'anna',
        },
        'phone_number': '',
        'is_contact': false,
        'is_mutual_contact': false,
        'is_premium': false,
        'type': {'@type': 'userTypeRegular'},
        'status': {'@type': 'userStatusEmpty'},
      });

      expect(hit?.userId, 3);
      expect(hit?.username, 'anna');
    });
  });
}
