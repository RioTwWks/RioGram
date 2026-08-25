import '../../models/user_models.dart';
import '../tdlib/tdlib_json.dart';

/// Парсинг TDLib user / userFullInfo / status / contacts.
class TdlibUserParser {
  const TdlibUserParser._();

  static UserSummary? parseUser(Map<String, dynamic>? json) {
    if (json == null || json['@type'] != 'user') {
      return null;
    }

    final userType = json['type'] as Map<String, dynamic>? ?? {};
    final isBot = userType['@type'] == 'userTypeBot';

    return UserSummary(
      id: tdIntOr(json['id']),
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      username: parseActiveUsername(json['usernames'] as Map<String, dynamic>?),
      phoneNumber: json['phone_number'] as String? ?? '',
      isContact: json['is_contact'] as bool? ?? false,
      isMutualContact: json['is_mutual_contact'] as bool? ?? false,
      isPremium: json['is_premium'] as bool? ?? false,
      isBot: isBot,
      status: parseUserStatus(json['status'] as Map<String, dynamic>?),
    );
  }

  static List<UserSummary> parseUsersFromList(List<dynamic>? users) {
    if (users == null) {
      return const [];
    }
    return users
        .whereType<Map<String, dynamic>>()
        .map(parseUser)
        .whereType<UserSummary>()
        .toList();
  }

  static UserStatusInfo parseUserStatus(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const UserStatusInfo(kind: UserStatusKind.empty);
    }

    return switch (json['@type']) {
      'userStatusOnline' => UserStatusInfo(
          kind: UserStatusKind.online,
          expiresAt: _dateFromSeconds(json['expires']),
        ),
      'userStatusOffline' => UserStatusInfo(
          kind: UserStatusKind.offline,
          wasOnlineAt: _dateFromSeconds(json['was_online']),
        ),
      'userStatusRecently' => UserStatusInfo(
          kind: UserStatusKind.recently,
          byMyPrivacySettings:
              json['by_my_privacy_settings'] as bool? ?? false,
        ),
      'userStatusLastWeek' => UserStatusInfo(
          kind: UserStatusKind.lastWeek,
          byMyPrivacySettings:
              json['by_my_privacy_settings'] as bool? ?? false,
        ),
      'userStatusLastMonth' => UserStatusInfo(
          kind: UserStatusKind.lastMonth,
          byMyPrivacySettings:
              json['by_my_privacy_settings'] as bool? ?? false,
        ),
      'userStatusEmpty' => const UserStatusInfo(kind: UserStatusKind.empty),
      _ => const UserStatusInfo(kind: UserStatusKind.unknown),
    };
  }

  static UserProfileFullInfo? parseUserFullInfo(
    Map<String, dynamic>? json, {
    required int userId,
  }) {
    if (json == null || json['@type'] != 'userFullInfo') {
      return null;
    }

    final bioRaw = json['bio'] as Map<String, dynamic>?;
    final bioText = bioRaw?['text'] as String? ?? '';
    final blockType =
        (json['block_list'] as Map<String, dynamic>?)?['@type'];

    return UserProfileFullInfo(
      userId: userId,
      bio: bioText,
      isBlocked: blockType == 'blockListMain',
      canBeCalled: json['can_be_called'] as bool? ?? false,
      supportsVideoCalls: json['supports_video_calls'] as bool? ?? false,
      groupInCommonCount: tdIntOr(json['group_in_common_count']),
      personalChatId: tdInt(json['personal_chat_id']),
    );
  }

  static String? parseActiveUsername(Map<String, dynamic>? usernames) {
    if (usernames == null || usernames['@type'] != 'usernames') {
      return null;
    }
    final active = usernames['active_usernames'] as List<dynamic>? ?? [];
    if (active.isNotEmpty) {
      return active.first as String;
    }
    final editable = usernames['editable_username'] as String?;
    if (editable != null && editable.isNotEmpty) {
      return editable;
    }
    return null;
  }

  static List<int> parseUserIds(Map<String, dynamic>? json) {
    if (json == null || json['@type'] != 'users') {
      return const [];
    }
    return (json['user_ids'] as List<dynamic>? ?? [])
        .map((id) => tdIntOr(id))
        .where((id) => id > 0)
        .toList();
  }

  static ImportedContactsResult parseImportedContacts(
    Map<String, dynamic>? json,
  ) {
    if (json == null || json['@type'] != 'importedContacts') {
      return const ImportedContactsResult();
    }
    final userIds = (json['user_ids'] as List<dynamic>? ?? [])
        .map((id) => tdIntOr(id))
        .where((id) => id > 0)
        .toList();
    final imported = (json['imported_contacts'] as List<dynamic>? ?? [])
        .length;
    return ImportedContactsResult(
      importedCount: imported,
      userIds: userIds,
    );
  }

  static List<BlockedUserSummary> parseBlockedSenders(
    Map<String, dynamic>? json,
  ) {
    if (json == null || json['@type'] != 'messageSenders') {
      return const [];
    }
    final senders = json['senders'] as List<dynamic>? ?? [];
    return senders
        .whereType<Map<String, dynamic>>()
        .map((sender) {
          if (sender['@type'] != 'messageSenderUser') {
            return null;
          }
          return BlockedUserSummary(
            userId: tdIntOr(sender['user_id']),
          );
        })
        .whereType<BlockedUserSummary>()
        .toList();
  }

  static List<CommonChatSummary> parseCommonChats(Map<String, dynamic>? json) {
    if (json == null || json['@type'] != 'chats') {
      return const [];
    }
    final chatIds = (json['chat_ids'] as List<dynamic>? ?? [])
        .map((id) => tdIntOr(id))
        .where((id) => id > 0)
        .toList();
    return chatIds
        .map((id) => CommonChatSummary(id: id, title: 'Чат $id'))
        .toList();
  }

  static DateTime? _dateFromSeconds(dynamic seconds) {
    final value = tdInt(seconds);
    if (value == null || value <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }
}
