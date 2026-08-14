/// Права участников чата (TDLib `chatPermissions`).
class ChatPermissionsInfo {
  const ChatPermissionsInfo({
    this.canSendBasicMessages = true,
    this.canSendAudios = true,
    this.canSendDocuments = true,
    this.canSendPhotos = true,
    this.canSendVideos = true,
    this.canSendVideoNotes = true,
    this.canSendVoiceNotes = true,
    this.canSendPolls = true,
    this.canSendOtherMessages = true,
    this.canAddLinkPreviews = true,
    this.canReactToMessages = true,
    this.canEditTag = true,
    this.canChangeInfo = false,
    this.canInviteUsers = false,
    this.canPinMessages = false,
    this.canCreateTopics = false,
  });

  final bool canSendBasicMessages;
  final bool canSendAudios;
  final bool canSendDocuments;
  final bool canSendPhotos;
  final bool canSendVideos;
  final bool canSendVideoNotes;
  final bool canSendVoiceNotes;
  final bool canSendPolls;
  final bool canSendOtherMessages;
  final bool canAddLinkPreviews;
  final bool canReactToMessages;
  final bool canEditTag;
  final bool canChangeInfo;
  final bool canInviteUsers;
  final bool canPinMessages;
  final bool canCreateTopics;

  Map<String, dynamic> toTdlib() {
    return {
      '@type': 'chatPermissions',
      'can_send_basic_messages': canSendBasicMessages,
      'can_send_audios': canSendAudios,
      'can_send_documents': canSendDocuments,
      'can_send_photos': canSendPhotos,
      'can_send_videos': canSendVideos,
      'can_send_video_notes': canSendVideoNotes,
      'can_send_voice_notes': canSendVoiceNotes,
      'can_send_polls': canSendPolls,
      'can_send_other_messages': canSendOtherMessages,
      'can_add_link_previews': canAddLinkPreviews,
      'can_react_to_messages': canReactToMessages,
      'can_edit_tag': canEditTag,
      'can_change_info': canChangeInfo,
      'can_invite_users': canInviteUsers,
      'can_pin_messages': canPinMessages,
      'can_create_topics': canCreateTopics,
    };
  }

  ChatPermissionsInfo copyWith({
    bool? canSendBasicMessages,
    bool? canSendAudios,
    bool? canSendDocuments,
    bool? canSendPhotos,
    bool? canSendVideos,
    bool? canSendVideoNotes,
    bool? canSendVoiceNotes,
    bool? canSendPolls,
    bool? canSendOtherMessages,
    bool? canAddLinkPreviews,
    bool? canReactToMessages,
    bool? canEditTag,
    bool? canChangeInfo,
    bool? canInviteUsers,
    bool? canPinMessages,
    bool? canCreateTopics,
  }) {
    return ChatPermissionsInfo(
      canSendBasicMessages: canSendBasicMessages ?? this.canSendBasicMessages,
      canSendAudios: canSendAudios ?? this.canSendAudios,
      canSendDocuments: canSendDocuments ?? this.canSendDocuments,
      canSendPhotos: canSendPhotos ?? this.canSendPhotos,
      canSendVideos: canSendVideos ?? this.canSendVideos,
      canSendVideoNotes: canSendVideoNotes ?? this.canSendVideoNotes,
      canSendVoiceNotes: canSendVoiceNotes ?? this.canSendVoiceNotes,
      canSendPolls: canSendPolls ?? this.canSendPolls,
      canSendOtherMessages:
          canSendOtherMessages ?? this.canSendOtherMessages,
      canAddLinkPreviews: canAddLinkPreviews ?? this.canAddLinkPreviews,
      canReactToMessages: canReactToMessages ?? this.canReactToMessages,
      canEditTag: canEditTag ?? this.canEditTag,
      canChangeInfo: canChangeInfo ?? this.canChangeInfo,
      canInviteUsers: canInviteUsers ?? this.canInviteUsers,
      canPinMessages: canPinMessages ?? this.canPinMessages,
      canCreateTopics: canCreateTopics ?? this.canCreateTopics,
    );
  }
}

/// Read-only настройки группы/канала для админов.
class ChatAdminSettings {
  const ChatAdminSettings({
    this.slowModeDelay = 0,
    this.slowModeDelayExpiresIn = 0,
    this.isSlowModeEnabled = false,
    this.hasAggressiveAntiSpamEnabled = false,
    this.joinByRequest = false,
    this.joinToSendMessages = false,
    this.isAllHistoryAvailable = true,
  });

  final int slowModeDelay;
  final double slowModeDelayExpiresIn;
  final bool isSlowModeEnabled;
  final bool hasAggressiveAntiSpamEnabled;
  final bool joinByRequest;
  final bool joinToSendMessages;
  final bool isAllHistoryAvailable;

  ChatAdminSettings copyWith({
    int? slowModeDelay,
    double? slowModeDelayExpiresIn,
    bool? isSlowModeEnabled,
    bool? hasAggressiveAntiSpamEnabled,
    bool? joinByRequest,
    bool? joinToSendMessages,
    bool? isAllHistoryAvailable,
  }) {
    return ChatAdminSettings(
      slowModeDelay: slowModeDelay ?? this.slowModeDelay,
      slowModeDelayExpiresIn:
          slowModeDelayExpiresIn ?? this.slowModeDelayExpiresIn,
      isSlowModeEnabled: isSlowModeEnabled ?? this.isSlowModeEnabled,
      hasAggressiveAntiSpamEnabled:
          hasAggressiveAntiSpamEnabled ?? this.hasAggressiveAntiSpamEnabled,
      joinByRequest: joinByRequest ?? this.joinByRequest,
      joinToSendMessages: joinToSendMessages ?? this.joinToSendMessages,
      isAllHistoryAvailable:
          isAllHistoryAvailable ?? this.isAllHistoryAvailable,
    );
  }

  ChatAdminSettings merge(ChatAdminSettings other) {
    return ChatAdminSettings(
      slowModeDelay:
          other.slowModeDelay > 0 ? other.slowModeDelay : slowModeDelay,
      slowModeDelayExpiresIn: other.slowModeDelayExpiresIn > 0
          ? other.slowModeDelayExpiresIn
          : slowModeDelayExpiresIn,
      isSlowModeEnabled: other.isSlowModeEnabled || isSlowModeEnabled,
      hasAggressiveAntiSpamEnabled:
          other.hasAggressiveAntiSpamEnabled || hasAggressiveAntiSpamEnabled,
      joinByRequest: other.joinByRequest || joinByRequest,
      joinToSendMessages: other.joinToSendMessages || joinToSendMessages,
      isAllHistoryAvailable: other.isAllHistoryAvailable && isAllHistoryAvailable,
    );
  }
}

/// Ссылка-приглашение в чат.
class ChatInviteLinkInfo {
  const ChatInviteLinkInfo({
    required this.url,
    this.name = '',
    this.isPrimary = false,
    this.isRevoked = false,
    this.memberCount = 0,
    this.createsJoinRequest = false,
  });

  final String url;
  final String name;
  final bool isPrimary;
  final bool isRevoked;
  final int memberCount;
  final bool createsJoinRequest;
}

/// Статус участника в чате.
enum ChatMemberStatusKind {
  unknown,
  creator,
  administrator,
  member,
  restricted,
  left,
  banned,
}

/// Участник чата.
class ChatMemberInfo {
  const ChatMemberInfo({
    required this.userId,
    this.displayName,
    this.tag = '',
    this.status = ChatMemberStatusKind.unknown,
    this.isOwner = false,
    this.canBeEdited = false,
    this.restrictedPermissions = const ChatPermissionsInfo(),
  });

  final int userId;
  final String? displayName;
  final String tag;
  final ChatMemberStatusKind status;
  final bool isOwner;
  final bool canBeEdited;
  final ChatPermissionsInfo restrictedPermissions;

  String get title {
    if (tag.isNotEmpty) {
      return tag;
    }
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!;
    }
    return 'User $userId';
  }

  String get statusLabel {
    return switch (status) {
      ChatMemberStatusKind.creator => 'Создатель',
      ChatMemberStatusKind.administrator => 'Админ',
      ChatMemberStatusKind.member => 'Участник',
      ChatMemberStatusKind.restricted => 'Ограничен',
      ChatMemberStatusKind.left => 'Покинул',
      ChatMemberStatusKind.banned => 'Заблокирован',
      ChatMemberStatusKind.unknown => '',
    };
  }

  bool get isBanned => status == ChatMemberStatusKind.banned;

  ChatMemberInfo copyWithDisplayName(String? displayName) {
    return ChatMemberInfo(
      userId: userId,
      displayName: displayName ?? this.displayName,
      tag: tag,
      status: status,
      isOwner: isOwner,
      canBeEdited: canBeEdited,
      restrictedPermissions: restrictedPermissions,
    );
  }
}

/// Детальная информация о чате для экрана управления.
class ChatDetailInfo {
  const ChatDetailInfo({
    required this.chatId,
    this.description = '',
    this.username,
    this.memberCount,
    this.inviteLink,
    this.permissions = const ChatPermissionsInfo(),
    this.adminSettings = const ChatAdminSettings(),
    this.myStatus = ChatMemberStatusKind.unknown,
    this.canManageMembers = false,
    this.canChangeInfo = false,
    this.canUpgradeToSupergroup = false,
    this.upgradedToSupergroupId,
  });

  final int chatId;
  final String description;
  final String? username;
  final int? memberCount;
  final ChatInviteLinkInfo? inviteLink;
  final ChatPermissionsInfo permissions;
  final ChatAdminSettings adminSettings;
  final ChatMemberStatusKind myStatus;
  final bool canManageMembers;
  final bool canChangeInfo;
  final bool canUpgradeToSupergroup;
  final int? upgradedToSupergroupId;

  bool get isGroupLike =>
      myStatus != ChatMemberStatusKind.unknown ||
      memberCount != null ||
      inviteLink != null;

  ChatDetailInfo merge(ChatDetailInfo other) {
    if (other.chatId != chatId) {
      return other;
    }
    return ChatDetailInfo(
      chatId: chatId,
      description: other.description.isNotEmpty ? other.description : description,
      username: other.username ?? username,
      memberCount: other.memberCount ?? memberCount,
      inviteLink: other.inviteLink ?? inviteLink,
      permissions: other.permissions != const ChatPermissionsInfo()
          ? other.permissions
          : permissions,
      adminSettings: adminSettings.merge(other.adminSettings),
      myStatus: other.myStatus != ChatMemberStatusKind.unknown
          ? other.myStatus
          : myStatus,
      canManageMembers: other.canManageMembers || canManageMembers,
      canChangeInfo: other.canChangeInfo || canChangeInfo,
      canUpgradeToSupergroup:
          other.canUpgradeToSupergroup || canUpgradeToSupergroup,
      upgradedToSupergroupId:
          other.upgradedToSupergroupId ?? upgradedToSupergroupId,
    );
  }

  ChatDetailInfo copyWithPermissions(ChatPermissionsInfo permissions) {
    return ChatDetailInfo(
      chatId: chatId,
      description: description,
      username: username,
      memberCount: memberCount,
      inviteLink: inviteLink,
      permissions: permissions,
      adminSettings: adminSettings,
      myStatus: myStatus,
      canManageMembers: canManageMembers,
      canChangeInfo: canChangeInfo,
      canUpgradeToSupergroup: canUpgradeToSupergroup,
      upgradedToSupergroupId: upgradedToSupergroupId,
    );
  }

  ChatDetailInfo copyWithInviteLink(ChatInviteLinkInfo inviteLink) {
    return ChatDetailInfo(
      chatId: chatId,
      description: description,
      username: username,
      memberCount: memberCount,
      inviteLink: inviteLink,
      permissions: permissions,
      adminSettings: adminSettings,
      myStatus: myStatus,
      canManageMembers: canManageMembers,
      canChangeInfo: canChangeInfo,
      canUpgradeToSupergroup: canUpgradeToSupergroup,
      upgradedToSupergroupId: upgradedToSupergroupId,
    );
  }
}
