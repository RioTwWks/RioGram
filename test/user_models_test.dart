import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/user/tdlib_user_parser.dart';
import 'package:riogram/core/user/user_status_formatter.dart';
import 'package:riogram/models/user_models.dart';

void main() {
  group('TdlibUserParser', () {
    test('parseUser extracts names and username', () {
      final user = TdlibUserParser.parseUser({
        '@type': 'user',
        'id': 42,
        'first_name': 'Ivan',
        'last_name': 'Petrov',
        'usernames': {
          '@type': 'usernames',
          'active_usernames': ['ivan_p'],
          'disabled_usernames': [],
          'editable_username': 'ivan_p',
        },
        'phone_number': '',
        'is_contact': true,
        'is_mutual_contact': false,
        'is_premium': false,
        'type': {'@type': 'userTypeRegular'},
        'status': {'@type': 'userStatusOnline', 'expires': 9999999999},
      });

      expect(user, isNotNull);
      expect(user!.displayName, 'Ivan Petrov');
      expect(user.username, 'ivan_p');
      expect(user.isContact, isTrue);
      expect(user.status.kind, UserStatusKind.online);
    });

    test('parseUserFullInfo reads bio and block state', () {
      final info = TdlibUserParser.parseUserFullInfo(
        {
          '@type': 'userFullInfo',
          'bio': {
            '@type': 'formattedText',
            'text': 'Hello world',
            'entities': [],
          },
          'block_list': {'@type': 'blockListMain'},
          'can_be_called': true,
          'supports_video_calls': true,
          'group_in_common_count': 3,
        },
        userId: 7,
      );

      expect(info, isNotNull);
      expect(info!.bio, 'Hello world');
      expect(info.isBlocked, isTrue);
      expect(info.groupInCommonCount, 3);
    });

    test('parseImportedContacts counts imported entries', () {
      final result = TdlibUserParser.parseImportedContacts({
        '@type': 'importedContacts',
        'user_ids': [1, 2],
        'imported_contacts': [
          {'@type': 'importedContact', 'user_id': 1},
          {'@type': 'importedContact', 'user_id': 2},
        ],
        'retry_contacts': [],
      });

      expect(result.importedCount, 2);
      expect(result.userIds, [1, 2]);
    });

    test('parseBlockedSenders extracts user ids', () {
      final blocked = TdlibUserParser.parseBlockedSenders({
        '@type': 'messageSenders',
        'senders': [
          {'@type': 'messageSenderUser', 'user_id': 5},
        ],
        'total_count': 1,
      });

      expect(blocked, hasLength(1));
      expect(blocked.first.userId, 5);
    });
  });

  group('UserStatusFormatter', () {
    test('online status', () {
      expect(
        UserStatusFormatter.format(
          const UserStatusInfo(kind: UserStatusKind.online),
        ),
        'в сети',
      );
    });

    test('recently status', () {
      expect(
        UserStatusFormatter.format(
          const UserStatusInfo(kind: UserStatusKind.recently),
        ),
        'был(а) недавно',
      );
    });

    test('offline with was online time', () {
      final now = DateTime(2026, 1, 15, 12, 0);
      final wasOnline = now.subtract(const Duration(minutes: 5));
      expect(
        UserStatusFormatter.format(
          UserStatusInfo(
            kind: UserStatusKind.offline,
            wasOnlineAt: wasOnline,
          ),
          now: now,
        ),
        'был(а) 5 мин. назад',
      );
    });
  });

  group('UserSummary', () {
    test('displayName falls back to username', () {
      const user = UserSummary(
        id: 1,
        firstName: '',
        lastName: '',
        username: 'bot_user',
      );
      expect(user.displayName, 'bot_user');
    });
  });
}
