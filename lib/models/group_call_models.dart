/// Фаза UI группового звонка.
enum GroupCallUiPhase {
  idle,
  joining,
  active,
  leaving,
  ended,
}

/// Сводка группового / video chat звонка.
class GroupCallSummary {
  const GroupCallSummary({
    required this.id,
    required this.title,
    this.chatId,
    this.isVideoChat = true,
    this.isJoined = false,
    this.isActive = false,
    this.participantCount = 0,
    this.isMyVideoEnabled = false,
    this.canEnableVideo = false,
    this.inviteLink = '',
    this.phase = GroupCallUiPhase.idle,
  });

  final int id;
  final String title;
  final int? chatId;
  final bool isVideoChat;
  final bool isJoined;
  final bool isActive;
  final int participantCount;
  final bool isMyVideoEnabled;
  final bool canEnableVideo;
  final String inviteLink;
  final GroupCallUiPhase phase;

  bool get hasActiveCall =>
      phase == GroupCallUiPhase.joining || phase == GroupCallUiPhase.active;

  GroupCallSummary copyWith({
    int? id,
    String? title,
    int? chatId,
    bool? isVideoChat,
    bool? isJoined,
    bool? isActive,
    int? participantCount,
    bool? isMyVideoEnabled,
    bool? canEnableVideo,
    String? inviteLink,
    GroupCallUiPhase? phase,
  }) {
    return GroupCallSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      chatId: chatId ?? this.chatId,
      isVideoChat: isVideoChat ?? this.isVideoChat,
      isJoined: isJoined ?? this.isJoined,
      isActive: isActive ?? this.isActive,
      participantCount: participantCount ?? this.participantCount,
      isMyVideoEnabled: isMyVideoEnabled ?? this.isMyVideoEnabled,
      canEnableVideo: canEnableVideo ?? this.canEnableVideo,
      inviteLink: inviteLink ?? this.inviteLink,
      phase: phase ?? this.phase,
    );
  }
}

/// Участник группового звонка.
class GroupCallParticipantSummary {
  const GroupCallParticipantSummary({
    required this.userId,
    this.displayName,
    this.isCurrentUser = false,
    this.isSpeaking = false,
    this.isMutedForAll = false,
    this.isMutedForCurrentUser = false,
    this.isHandRaised = false,
    this.volumeLevel = 0,
    this.audioSourceId = 0,
  });

  final int userId;
  final String? displayName;
  final bool isCurrentUser;
  final bool isSpeaking;
  final bool isMutedForAll;
  final bool isMutedForCurrentUser;
  final bool isHandRaised;
  final int volumeLevel;
  final int audioSourceId;

  bool get isMuted => isMutedForAll || isMutedForCurrentUser;

  GroupCallParticipantSummary copyWith({
    String? displayName,
    bool? isCurrentUser,
    bool? isSpeaking,
    bool? isMutedForAll,
    bool? isMutedForCurrentUser,
    bool? isHandRaised,
    int? volumeLevel,
    int? audioSourceId,
  }) {
    return GroupCallParticipantSummary(
      userId: userId,
      displayName: displayName ?? this.displayName,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isMutedForAll: isMutedForAll ?? this.isMutedForAll,
      isMutedForCurrentUser:
          isMutedForCurrentUser ?? this.isMutedForCurrentUser,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      volumeLevel: volumeLevel ?? this.volumeLevel,
      audioSourceId: audioSourceId ?? this.audioSourceId,
    );
  }
}
