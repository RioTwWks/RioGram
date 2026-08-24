import '../../models/group_call_models.dart';

/// Парсинг TDLib group call updates.
class TdlibGroupCallParser {
  const TdlibGroupCallParser._();

  static GroupCallSummary? parseGroupCall(
    Map<String, dynamic>? json, {
    int? chatId,
    GroupCallUiPhase? phase,
  }) {
    if (json == null || json['@type'] != 'groupCall') {
      return null;
    }

    return GroupCallSummary(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Групповой звонок',
      chatId: chatId,
      isVideoChat: json['is_video_chat'] as bool? ?? true,
      isJoined: json['is_joined'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? false,
      participantCount: json['participant_count'] as int? ?? 0,
      isMyVideoEnabled: json['is_my_video_enabled'] as bool? ?? false,
      canEnableVideo: json['can_enable_video'] as bool? ?? false,
      inviteLink: json['invite_link'] as String? ?? '',
      phase: phase ?? GroupCallUiPhase.idle,
    );
  }

  static GroupCallParticipantSummary? parseParticipant(
    Map<String, dynamic>? json,
  ) {
    if (json == null || json['@type'] != 'groupCallParticipant') {
      return null;
    }

    final participantId = json['participant_id'] as Map<String, dynamic>? ?? {};
    final userId = switch (participantId['@type']) {
      'messageSenderUser' => participantId['user_id'] as int? ?? 0,
      _ => 0,
    };

    return GroupCallParticipantSummary(
      userId: userId,
      isCurrentUser: json['is_current_user'] as bool? ?? false,
      isSpeaking: json['is_speaking'] as bool? ?? false,
      isMutedForAll: json['is_muted_for_all_users'] as bool? ?? false,
      isMutedForCurrentUser:
          json['is_muted_for_current_user'] as bool? ?? false,
      isHandRaised: json['is_hand_raised'] as bool? ?? false,
      volumeLevel: json['volume_level'] as int? ?? 0,
      audioSourceId: json['audio_source_id'] as int? ?? 0,
    );
  }

  static int? parseGroupCallId(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return switch (json['@type']) {
      'groupCallId' => json['id'] as int?,
      'groupCallInfo' => json['group_call_id'] as int?,
      'groupCall' => json['id'] as int?,
      _ => null,
    };
  }

  static String? parseJoinResponseText(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return switch (json['@type']) {
      'text' => json['text'] as String?,
      _ => null,
    };
  }
}
