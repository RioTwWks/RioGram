import '../../models/channel_models.dart';
import '../../models/chat_info_models.dart';

/// Парсинг TDLib-ответов для экрана информации о чате.
class TdlibChatInfoParser {
  const TdlibChatInfoParser._();

  static ChatPermissionsInfo parsePermissions(Map<String, dynamic>? json) {
    if (json == null || json['@type'] != 'chatPermissions') {
      return const ChatPermissionsInfo();
    }
    return ChatPermissionsInfo(
      canSendBasicMessages: json['can_send_basic_messages'] as bool? ?? true,
      canSendAudios: json['can_send_audios'] as bool? ?? true,
      canSendDocuments: json['can_send_documents'] as bool? ?? true,
      canSendPhotos: json['can_send_photos'] as bool? ?? true,
      canSendVideos: json['can_send_videos'] as bool? ?? true,
      canSendVideoNotes: json['can_send_video_notes'] as bool? ?? true,
      canSendVoiceNotes: json['can_send_voice_notes'] as bool? ?? true,
      canSendPolls: json['can_send_polls'] as bool? ?? true,
      canSendOtherMessages: json['can_send_other_messages'] as bool? ?? true,
      canAddLinkPreviews: json['can_add_link_previews'] as bool? ?? true,
      canReactToMessages: json['can_react_to_messages'] as bool? ?? true,
      canEditTag: json['can_edit_tag'] as bool? ?? true,
      canChangeInfo: json['can_change_info'] as bool? ?? false,
      canInviteUsers: json['can_invite_users'] as bool? ?? false,
      canPinMessages: json['can_pin_messages'] as bool? ?? false,
      canCreateTopics: json['can_create_topics'] as bool? ?? false,
    );
  }

  static ChatInviteLinkInfo? parseInviteLink(Map<String, dynamic>? json) {
    if (json == null || json['@type'] != 'chatInviteLink') {
      return null;
    }
    final url = json['invite_link'] as String?;
    if (url == null || url.isEmpty) {
      return null;
    }
    return ChatInviteLinkInfo(
      url: url,
      name: json['name'] as String? ?? '',
      isPrimary: json['is_primary'] as bool? ?? false,
      isRevoked: json['is_revoked'] as bool? ?? false,
      memberCount: json['member_count'] as int? ?? 0,
      createsJoinRequest: json['creates_join_request'] as bool? ?? false,
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

  static ChatMemberStatusKind parseMemberStatus(Map<String, dynamic>? status) {
    return switch (status?['@type']) {
      'chatMemberStatusCreator' => ChatMemberStatusKind.creator,
      'chatMemberStatusAdministrator' => ChatMemberStatusKind.administrator,
      'chatMemberStatusMember' => ChatMemberStatusKind.member,
      'chatMemberStatusRestricted' => ChatMemberStatusKind.restricted,
      'chatMemberStatusLeft' => ChatMemberStatusKind.left,
      'chatMemberStatusBanned' => ChatMemberStatusKind.banned,
      _ => ChatMemberStatusKind.unknown,
    };
  }

  static bool parseCanManageMembers(Map<String, dynamic>? status) {
    if (status?['@type'] == 'chatMemberStatusCreator') {
      return true;
    }
    if (status?['@type'] != 'chatMemberStatusAdministrator') {
      return false;
    }
    final rights = status!['rights'] as Map<String, dynamic>?;
    return rights?['can_restrict_members'] as bool? ?? false;
  }

  static bool parseCanChangeInfo(Map<String, dynamic>? status) {
    if (status?['@type'] == 'chatMemberStatusCreator') {
      return true;
    }
    if (status?['@type'] != 'chatMemberStatusAdministrator') {
      return false;
    }
    final rights = status!['rights'] as Map<String, dynamic>?;
    return rights?['can_change_info'] as bool? ?? false;
  }

  static bool parseCanPostMessages(Map<String, dynamic>? status) {
    if (status?['@type'] == 'chatMemberStatusCreator') {
      return true;
    }
    if (status?['@type'] != 'chatMemberStatusAdministrator') {
      return false;
    }
    final rights = status!['rights'] as Map<String, dynamic>?;
    return rights?['can_post_messages'] as bool? ?? false;
  }

  static ChatMemberInfo parseChatMember(Map<String, dynamic> json) {
    final memberId = json['member_id'] as Map<String, dynamic>? ?? {};
    final userId = switch (memberId['@type']) {
      'messageSenderUser' => memberId['user_id'] as int? ?? 0,
      _ => 0,
    };
    final statusJson = json['status'] as Map<String, dynamic>?;
    final status = parseMemberStatus(statusJson);
    final canBeEdited =
        statusJson?['can_be_edited'] as bool? ?? false;
    ChatPermissionsInfo restrictedPermissions = const ChatPermissionsInfo();
    if (status == ChatMemberStatusKind.restricted) {
      restrictedPermissions = parsePermissions(
        statusJson?['permissions'] as Map<String, dynamic>?,
      );
    }

    return ChatMemberInfo(
      userId: userId,
      tag: json['tag'] as String? ?? '',
      status: status,
      isOwner: status == ChatMemberStatusKind.creator,
      canBeEdited: canBeEdited,
      restrictedPermissions: restrictedPermissions,
    );
  }

  static List<ChatMemberInfo> parseChatMembers(Map<String, dynamic> json) {
    if (json['@type'] != 'chatMembers') {
      return const [];
    }
    final members = json['members'] as List<dynamic>? ?? [];
    return members
        .whereType<Map<String, dynamic>>()
        .map(parseChatMember)
        .where((member) => member.userId != 0)
        .toList();
  }

  static int? parseChatMembersTotalCount(Map<String, dynamic> json) {
    if (json['@type'] != 'chatMembers') {
      return null;
    }
    return json['total_count'] as int?;
  }

  static ChatDetailInfo parseChatForInfo(
    Map<String, dynamic> chat, {
    required int chatId,
  }) {
    return ChatDetailInfo(
      chatId: chatId,
      permissions: parsePermissions(
        chat['permissions'] as Map<String, dynamic>?,
      ),
    );
  }

  static ChatDetailInfo parseBasicGroupFullInfo(
    Map<String, dynamic> json, {
    required int chatId,
  }) {
    if (json['@type'] != 'basicGroupFullInfo') {
      return ChatDetailInfo(chatId: chatId);
    }
    final members = parseChatMembers({
      '@type': 'chatMembers',
      'total_count': (json['members'] as List<dynamic>? ?? []).length,
      'members': json['members'],
    });
    return ChatDetailInfo(
      chatId: chatId,
      description: json['description'] as String? ?? '',
      memberCount: members.length,
      inviteLink: parseInviteLink(
        json['invite_link'] as Map<String, dynamic>?,
      ),
    );
  }

  static ChatDetailInfo parseBasicGroupMeta(
    Map<String, dynamic> json, {
    required int chatId,
  }) {
    if (json['@type'] != 'basicGroup') {
      return ChatDetailInfo(chatId: chatId);
    }
    final status = json['status'] as Map<String, dynamic>?;
    final upgradedId = json['upgraded_to_supergroup_id'] as int? ?? 0;
    final isActive = json['is_active'] as bool? ?? true;
    return ChatDetailInfo(
      chatId: chatId,
      memberCount: json['member_count'] as int?,
      myStatus: parseMemberStatus(status),
      canManageMembers: parseCanManageMembers(status),
      canChangeInfo: parseCanChangeInfo(status),
      canUpgradeToSupergroup: isActive && upgradedId == 0,
      upgradedToSupergroupId: upgradedId == 0 ? null : upgradedId,
    );
  }

  static ChatDetailInfo parseSupergroup(
    Map<String, dynamic> json, {
    required int chatId,
  }) {
    if (json['@type'] != 'supergroup') {
      return ChatDetailInfo(chatId: chatId);
    }
    final status = json['status'] as Map<String, dynamic>?;
    return ChatDetailInfo(
      chatId: chatId,
      username: parseActiveUsername(json['usernames'] as Map<String, dynamic>?),
      memberCount: json['member_count'] as int?,
      myStatus: parseMemberStatus(status),
      canManageMembers: parseCanManageMembers(status),
      canChangeInfo: parseCanChangeInfo(status),
      canPostMessages: parseCanPostMessages(status),
      hasLinkedChat: json['has_linked_chat'] as bool? ?? false,
      adminSettings: ChatAdminSettings(
        isSlowModeEnabled: json['is_slow_mode_enabled'] as bool? ?? false,
        joinByRequest: json['join_by_request'] as bool? ?? false,
        joinToSendMessages: json['join_to_send_messages'] as bool? ?? false,
      ),
    );
  }

  static ChatDetailInfo parseSupergroupFullInfo(
    Map<String, dynamic> json, {
    required int chatId,
  }) {
    if (json['@type'] != 'supergroupFullInfo') {
      return ChatDetailInfo(chatId: chatId);
    }
    return ChatDetailInfo(
      chatId: chatId,
      description: json['description'] as String? ?? '',
      memberCount: json['member_count'] as int?,
      inviteLink: parseInviteLink(
        json['invite_link'] as Map<String, dynamic>?,
      ),
      linkedChatId: _parseLinkedChatId(json['linked_chat_id']),
      adminSettings: ChatAdminSettings(
        slowModeDelay: json['slow_mode_delay'] as int? ?? 0,
        slowModeDelayExpiresIn:
            (json['slow_mode_delay_expires_in'] as num?)?.toDouble() ?? 0,
        hasAggressiveAntiSpamEnabled:
            json['has_aggressive_anti_spam_enabled'] as bool? ?? false,
        isAllHistoryAvailable:
            json['is_all_history_available'] as bool? ?? true,
      ),
    );
  }

  static bool parseCanBePinned(Map<String, dynamic> message) {
    final properties = message['properties'] as Map<String, dynamic>?;
    if (properties != null) {
      return properties['can_be_pinned'] as bool? ?? false;
    }
    return message['can_be_pinned'] as bool? ?? false;
  }

  static bool parseIsPinned(Map<String, dynamic> message) {
    return message['is_pinned'] as bool? ?? false;
  }

  static MessageThreadContext? parseMessageThreadInfo(
    Map<String, dynamic> json, {
    required int channelChatId,
    required int channelMessageId,
    String? postPreview,
  }) {
    if (json['@type'] != 'messageThreadInfo') {
      return null;
    }
    final threadId = json['message_thread_id'] as int? ?? 0;
    final discussionChatId = json['chat_id'] as int? ?? 0;
    if (threadId == 0 || discussionChatId == 0) {
      return null;
    }
    return MessageThreadContext(
      channelChatId: channelChatId,
      channelMessageId: channelMessageId,
      discussionChatId: discussionChatId,
      messageThreadId: threadId,
      postPreview: postPreview,
    );
  }

  static int? _parseLinkedChatId(dynamic value) {
    final id = value as int? ?? 0;
    return id == 0 ? null : id;
  }
}
