import 'package:riogram/core/chat/tdlib_chat_info_parser.dart';
import 'package:riogram/models/chat_info_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TdlibChatInfoParser', () {
    test('parsePermissions читает флаги chatPermissions', () {
      final permissions = TdlibChatInfoParser.parsePermissions({
        '@type': 'chatPermissions',
        'can_send_basic_messages': false,
        'can_send_audios': true,
        'can_send_documents': true,
        'can_send_photos': true,
        'can_send_videos': true,
        'can_send_video_notes': true,
        'can_send_voice_notes': true,
        'can_send_polls': false,
        'can_send_other_messages': true,
        'can_add_link_previews': true,
        'can_react_to_messages': true,
        'can_edit_tag': true,
        'can_change_info': true,
        'can_invite_users': true,
        'can_pin_messages': true,
        'can_create_topics': false,
      });

      expect(permissions.canSendBasicMessages, isFalse);
      expect(permissions.canSendPolls, isFalse);
      expect(permissions.canPinMessages, isTrue);
      expect(permissions.canChangeInfo, isTrue);
    });

    test('parseInviteLink извлекает URL и флаги', () {
      final link = TdlibChatInfoParser.parseInviteLink({
        '@type': 'chatInviteLink',
        'invite_link': 'https://t.me/+abc',
        'name': 'Main',
        'is_primary': true,
        'is_revoked': false,
        'member_count': 12,
        'creates_join_request': true,
      });

      expect(link?.url, 'https://t.me/+abc');
      expect(link?.isPrimary, isTrue);
      expect(link?.createsJoinRequest, isTrue);
      expect(link?.memberCount, 12);
    });

    test('parseSupergroupFullInfo собирает описание и slow mode', () {
      final info = TdlibChatInfoParser.parseSupergroupFullInfo(
        {
          '@type': 'supergroupFullInfo',
          'description': 'Test group',
          'member_count': 42,
          'slow_mode_delay': 30,
          'has_aggressive_anti_spam_enabled': true,
          'join_by_request': false,
          'is_all_history_available': false,
          'invite_link': {
            '@type': 'chatInviteLink',
            'invite_link': 'https://t.me/+invite',
            'is_primary': true,
          },
        },
        chatId: 100,
      );

      expect(info.description, 'Test group');
      expect(info.memberCount, 42);
      expect(info.inviteLink?.url, 'https://t.me/+invite');
      expect(info.adminSettings.slowModeDelay, 30);
      expect(info.adminSettings.hasAggressiveAntiSpamEnabled, isTrue);
      expect(info.adminSettings.isAllHistoryAvailable, isFalse);
    });

    test('parseChatMembers возвращает участников', () {
      final members = TdlibChatInfoParser.parseChatMembers({
        '@type': 'chatMembers',
        'total_count': 2,
        'members': [
          {
            '@type': 'chatMember',
            'member_id': {
              '@type': 'messageSenderUser',
              'user_id': 7,
            },
            'tag': 'Admin',
            'status': {
              '@type': 'chatMemberStatusAdministrator',
              'can_be_edited': true,
              'rights': {
                '@type': 'chatAdministratorRights',
                'can_restrict_members': true,
              },
            },
          },
          {
            '@type': 'chatMember',
            'member_id': {
              '@type': 'messageSenderUser',
              'user_id': 8,
            },
            'tag': '',
            'status': {'@type': 'chatMemberStatusMember'},
          },
        ],
      });

      expect(members.length, 2);
      expect(members.first.userId, 7);
      expect(members.first.tag, 'Admin');
      expect(members.first.status, ChatMemberStatusKind.administrator);
    });

    test('parseBasicGroupMeta определяет возможность апгрейда', () {
      final info = TdlibChatInfoParser.parseBasicGroupMeta(
        {
          '@type': 'basicGroup',
          'member_count': 5,
          'is_active': true,
          'upgraded_to_supergroup_id': 0,
          'status': {
            '@type': 'chatMemberStatusCreator',
            'is_anonymous': false,
            'is_member': true,
          },
        },
        chatId: 55,
      );

      expect(info.canUpgradeToSupergroup, isTrue);
      expect(info.myStatus, ChatMemberStatusKind.creator);
      expect(info.canManageMembers, isTrue);
    });
  });
}
