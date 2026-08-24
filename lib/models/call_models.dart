/// Состояние звонка TDLib (`CallState`).
enum CallStateKind {
  pending,
  exchangingKeys,
  ready,
  hangingUp,
  discarded,
  error,
  unknown,
}

/// Фаза UI звонка.
enum CallUiPhase {
  idle,
  outgoingRinging,
  incomingRinging,
  connecting,
  active,
  ending,
}

/// Причина завершения звонка.
enum CallDiscardReasonKind {
  empty,
  missed,
  declined,
  disconnected,
  hungUp,
  upgradeToGroupCall,
  unknown,
}

/// Возможности звонков пользователя из `userFullInfo`.
class UserCallCapabilities {
  const UserCallCapabilities({
    this.canBeCalled = false,
    this.supportsVideoCalls = false,
  });

  final bool canBeCalled;
  final bool supportsVideoCalls;

  static const none = UserCallCapabilities();
}

/// Сводка активного звонка.
class CallSummary {
  const CallSummary({
    required this.id,
    required this.userId,
    required this.isOutgoing,
    required this.isVideo,
    required this.stateKind,
    this.userDisplayName,
    this.discardReason,
    this.needRating = false,
    this.errorMessage,
  });

  final int id;
  final int userId;
  final String? userDisplayName;
  final bool isOutgoing;
  final bool isVideo;
  final CallStateKind stateKind;
  final CallDiscardReasonKind? discardReason;
  final bool needRating;
  final String? errorMessage;

  bool get isIncomingRinging =>
      !isOutgoing && stateKind == CallStateKind.pending;

  bool get isOutgoingRinging =>
      isOutgoing && stateKind == CallStateKind.pending;

  bool get isActive => stateKind == CallStateKind.ready;

  bool get isEnded =>
      stateKind == CallStateKind.discarded ||
      stateKind == CallStateKind.error;

  CallUiPhase get uiPhase {
    if (isEnded) {
      return CallUiPhase.ending;
    }
    return switch (stateKind) {
      CallStateKind.pending =>
        isOutgoing ? CallUiPhase.outgoingRinging : CallUiPhase.incomingRinging,
      CallStateKind.exchangingKeys => CallUiPhase.connecting,
      CallStateKind.ready => CallUiPhase.active,
      CallStateKind.hangingUp => CallUiPhase.ending,
      CallStateKind.discarded || CallStateKind.error => CallUiPhase.ending,
      CallStateKind.unknown => CallUiPhase.idle,
    };
  }

  CallSummary copyWith({
    CallStateKind? stateKind,
    String? userDisplayName,
    CallDiscardReasonKind? discardReason,
    bool? needRating,
    String? errorMessage,
  }) {
    return CallSummary(
      id: id,
      userId: userId,
      isOutgoing: isOutgoing,
      isVideo: isVideo,
      stateKind: stateKind ?? this.stateKind,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      discardReason: discardReason ?? this.discardReason,
      needRating: needRating ?? this.needRating,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Данные `callStateReady` для tgcalls/WebRTC.
class CallReadyPayload {
  const CallReadyPayload({
    required this.config,
    required this.encryptionKey,
    required this.customParameters,
    required this.allowP2p,
    this.servers = const [],
  });

  final String config;
  final List<int> encryptionKey;
  final String customParameters;
  final bool allowP2p;
  final List<Map<String, dynamic>> servers;
}

/// Содержимое служебного сообщения `messageCall`.
class CallMessageInfo {
  const CallMessageInfo({
    required this.isVideo,
    required this.durationSeconds,
    required this.discardReason,
    required this.isMissed,
    required this.isDeclined,
    required this.isIncoming,
  });

  final bool isVideo;
  final int durationSeconds;
  final CallDiscardReasonKind discardReason;
  final bool isMissed;
  final bool isDeclined;
  final bool isIncoming;

  factory CallMessageInfo.fromTdlib(
    Map<String, dynamic> content, {
    required bool isOutgoing,
  }) {
    final reasonType =
        (content['discard_reason'] as Map<String, dynamic>?)?['@type'];
    final reason = switch (reasonType) {
      'callDiscardReasonMissed' => CallDiscardReasonKind.missed,
      'callDiscardReasonDeclined' => CallDiscardReasonKind.declined,
      'callDiscardReasonDisconnected' => CallDiscardReasonKind.disconnected,
      'callDiscardReasonHungUp' => CallDiscardReasonKind.hungUp,
      'callDiscardReasonUpgradeToGroupCall' =>
        CallDiscardReasonKind.upgradeToGroupCall,
      'callDiscardReasonEmpty' => CallDiscardReasonKind.empty,
      _ => CallDiscardReasonKind.unknown,
    };

    return CallMessageInfo(
      isVideo: content['is_video'] as bool? ?? false,
      durationSeconds: content['duration'] as int? ?? 0,
      discardReason: reason,
      isMissed: reason == CallDiscardReasonKind.missed,
      isDeclined: reason == CallDiscardReasonKind.declined,
      isIncoming: !isOutgoing,
    );
  }

  String preview({required bool isOutgoing}) {
    if (isMissed) {
      return isOutgoing ? 'Нет ответа' : 'Пропущенный звонок';
    }
    if (isDeclined) {
      return isOutgoing ? 'Звонок отклонён' : 'Отклонённый звонок';
    }
    if (durationSeconds > 0) {
      final minutes = durationSeconds ~/ 60;
      final seconds = durationSeconds % 60;
      final duration = minutes > 0
          ? '$minutes:${seconds.toString().padLeft(2, '0')}'
          : '$secondsс';
      final kind = isVideo ? 'Видеозвонок' : 'Звонок';
      return '$kind ($duration)';
    }
    final kind = isVideo ? 'Видеозвонок' : 'Звонок';
    return isOutgoing ? 'Исходящий $kind' : 'Входящий $kind';
  }
}
