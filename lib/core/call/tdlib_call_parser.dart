import '../../models/call_models.dart';

/// Парсинг TDLib call / userFullInfo / messageCall.
class TdlibCallParser {
  const TdlibCallParser._();

  static const defaultLibraryVersions = ['2.6', '3.0'];

  static Map<String, dynamic> defaultCallProtocol() => {
        '@type': 'callProtocol',
        'udp_p2p': true,
        'udp_reflector': true,
        'min_layer': 65,
        'max_layer': 92,
        'library_versions': defaultLibraryVersions,
      };

  static CallSummary? parseCall(Map<String, dynamic>? json) {
    if (json == null || json['@type'] != 'call') {
      return null;
    }

    final state = json['state'] as Map<String, dynamic>? ?? {};
    final stateKind = parseCallStateKind(state);
    final discardReason = stateKind == CallStateKind.discarded
        ? parseDiscardReason(
            state['reason'] as Map<String, dynamic>?,
          )
        : null;

    return CallSummary(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      isOutgoing: json['is_outgoing'] as bool? ?? false,
      isVideo: json['is_video'] as bool? ?? false,
      stateKind: stateKind,
      discardReason: discardReason,
      needRating: state['need_rating'] as bool? ?? false,
      errorMessage: stateKind == CallStateKind.error
          ? _parseErrorMessage(state['error'] as Map<String, dynamic>?)
          : null,
    );
  }

  static CallStateKind parseCallStateKind(Map<String, dynamic>? state) {
    return switch (state?['@type']) {
      'callStatePending' => CallStateKind.pending,
      'callStateExchangingKeys' => CallStateKind.exchangingKeys,
      'callStateReady' => CallStateKind.ready,
      'callStateHangingUp' => CallStateKind.hangingUp,
      'callStateDiscarded' => CallStateKind.discarded,
      'callStateError' => CallStateKind.error,
      _ => CallStateKind.unknown,
    };
  }

  static CallDiscardReasonKind parseDiscardReason(Map<String, dynamic>? reason) {
    return switch (reason?['@type']) {
      'callDiscardReasonEmpty' => CallDiscardReasonKind.empty,
      'callDiscardReasonMissed' => CallDiscardReasonKind.missed,
      'callDiscardReasonDeclined' => CallDiscardReasonKind.declined,
      'callDiscardReasonDisconnected' => CallDiscardReasonKind.disconnected,
      'callDiscardReasonHungUp' => CallDiscardReasonKind.hungUp,
      'callDiscardReasonUpgradeToGroupCall' =>
        CallDiscardReasonKind.upgradeToGroupCall,
      _ => CallDiscardReasonKind.unknown,
    };
  }

  static CallReadyPayload? parseCallReadyPayload(Map<String, dynamic>? state) {
    if (state?['@type'] != 'callStateReady') {
      return null;
    }

    final encryptionKeyRaw = state['encryption_key'];
    final encryptionKey = encryptionKeyRaw is List
        ? encryptionKeyRaw.whereType<int>().toList()
        : <int>[];

    final serversRaw = state['servers'] as List<dynamic>? ?? [];
    final servers = serversRaw.whereType<Map<String, dynamic>>().toList();

    return CallReadyPayload(
      config: state['config'] as String? ?? '',
      encryptionKey: encryptionKey,
      customParameters: state['custom_parameters'] as String? ?? '',
      allowP2p: state['allow_p2p'] as bool? ?? false,
      servers: servers,
    );
  }

  static UserCallCapabilities parseUserCallCapabilities(
    Map<String, dynamic>? json,
  ) {
    if (json == null || json['@type'] != 'userFullInfo') {
      return UserCallCapabilities.none;
    }
    return UserCallCapabilities(
      canBeCalled: json['can_be_called'] as bool? ?? false,
      supportsVideoCalls: json['supports_video_calls'] as bool? ?? false,
    );
  }

  static CallMessageInfo parseCallMessage(
    Map<String, dynamic> content, {
    required bool isOutgoing,
  }) {
    final reason = parseDiscardReason(
      content['discard_reason'] as Map<String, dynamic>?,
    );
    final duration = content['duration'] as int? ?? 0;
    final isVideo = content['is_video'] as bool? ?? false;
    final isMissed = reason == CallDiscardReasonKind.missed;
    final isDeclined = reason == CallDiscardReasonKind.declined;

    return CallMessageInfo(
      isVideo: isVideo,
      durationSeconds: duration,
      discardReason: reason,
      isMissed: isMissed,
      isDeclined: isDeclined,
      isIncoming: !isOutgoing,
    );
  }

  static String statusLabel(CallSummary call) {
    return switch (call.uiPhase) {
      CallUiPhase.outgoingRinging => 'Вызов…',
      CallUiPhase.incomingRinging => 'Входящий звонок',
      CallUiPhase.connecting => 'Соединение…',
      CallUiPhase.active => call.isVideo ? 'Видеозвонок' : 'Звонок',
      CallUiPhase.ending => _discardLabel(call.discardReason),
      CallUiPhase.idle => 'Звонок',
    };
  }

  static String _discardLabel(CallDiscardReasonKind? reason) {
    return switch (reason) {
      CallDiscardReasonKind.missed => 'Нет ответа',
      CallDiscardReasonKind.declined => 'Отклонён',
      CallDiscardReasonKind.disconnected => 'Соединение прервано',
      CallDiscardReasonKind.hungUp => 'Завершён',
      CallDiscardReasonKind.upgradeToGroupCall => 'Переведён в групповой',
      _ => 'Завершён',
    };
  }

  static String? _parseErrorMessage(Map<String, dynamic>? error) {
    if (error == null) {
      return 'Ошибка звонка';
    }
    final message = error['message'] as String?;
    return message?.isNotEmpty == true ? message : 'Ошибка звонка';
  }
}
