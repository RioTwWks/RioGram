import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/group_call_models.dart';
import '../tdlib/tdlib_client.dart';
import 'call_platform_service.dart';
import 'call_signaling_bridge.dart';
import 'tdlib_group_call_parser.dart';

/// Групповые звонки / video chat через TDLib.
class GroupCallManager extends ChangeNotifier {
  GroupCallManager({
    required TdlibClient client,
    required CallSignalingBridge signalingBridge,
  })  : _client = client,
        _signalingBridge = signalingBridge;

  final TdlibClient _client;
  final CallSignalingBridge _signalingBridge;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  GroupCallSummary? _activeCall;
  final List<GroupCallParticipantSummary> _participants = [];
  String? _lastError;
  var _isMuted = false;
  var _isVideoEnabled = false;
  String? _platformCallUuid;

  GroupCallSummary? get activeCall => _activeCall;
  List<GroupCallParticipantSummary> get participants =>
      List.unmodifiable(_participants);
  String? get lastError => _lastError;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get hasActiveGroupCall => _activeCall?.hasActiveCall ?? false;

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> startVideoChat({
    required int chatId,
    String title = '',
    bool isVideo = false,
  }) async {
    if (_activeCall?.hasActiveCall ?? false) {
      _lastError = 'Уже есть активный групповой звонок';
      notifyListeners();
      return;
    }

    _lastError = null;
    _client.send({
      '@type': 'createVideoChat',
      'chat_id': chatId,
      'title': title,
      'start_date': 0,
      'is_rtmp_stream': false,
      '@extra': 'createVideoChat_$chatId',
    });

    _activeCall = GroupCallSummary(
      id: 0,
      title: title.isNotEmpty ? title : 'Video chat',
      chatId: chatId,
      phase: GroupCallUiPhase.joining,
    );
    _isVideoEnabled = isVideo;
    notifyListeners();
  }

  Future<void> joinActiveGroupCall({
    required int groupCallId,
    bool isVideo = false,
  }) async {
    _lastError = null;
    _isVideoEnabled = isVideo;
    _activeCall = (_activeCall ??
            GroupCallSummary(
              id: groupCallId,
              title: 'Групповой звонок',
              phase: GroupCallUiPhase.joining,
            ))
        .copyWith(id: groupCallId, phase: GroupCallUiPhase.joining);
    notifyListeners();

    final joinParams = await _signalingBridge.buildGroupCallJoinParams(
      isMuted: _isMuted,
      isVideo: isVideo,
    );

    _client.send({
      '@type': 'joinVideoChat',
      'group_call_id': groupCallId,
      'participant_id': null,
      'join_parameters': joinParams.toTdlib(),
      'invite_hash': '',
      '@extra': 'joinVideoChat_$groupCallId',
    });
  }

  Future<void> createAndJoinStandaloneGroupCall({bool isVideo = false}) async {
    _lastError = null;
    _isVideoEnabled = isVideo;
    _activeCall = GroupCallSummary(
      id: 0,
      title: 'Конференция',
      isVideoChat: false,
      phase: GroupCallUiPhase.joining,
    );
    notifyListeners();

    final joinParams = await _signalingBridge.buildGroupCallJoinParams(
      isMuted: _isMuted,
      isVideo: isVideo,
    );

    _client.send({
      '@type': 'createGroupCall',
      'join_parameters': joinParams.toTdlib(),
      '@extra': 'createGroupCall',
    });
  }

  Future<void> leaveGroupCall() async {
    final call = _activeCall;
    if (call == null || call.id == 0) {
      _resetState();
      notifyListeners();
      return;
    }

    _activeCall = call.copyWith(phase: GroupCallUiPhase.leaving);
    notifyListeners();

    _client.send({
      '@type': 'leaveGroupCall',
      'group_call_id': call.id,
    });
    await _signalingBridge.onCallEnded();
    await _stopPlatformCall();
    _resetState();
    notifyListeners();
  }

  Future<void> endGroupCall() async {
    final call = _activeCall;
    if (call == null || call.id == 0) {
      return;
    }
    _client.send({
      '@type': 'endGroupCall',
      'group_call_id': call.id,
    });
    await leaveGroupCall();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    unawaited(_signalingBridge.setMuted(_isMuted));
    notifyListeners();
  }

  Future<void> toggleVideo() async {
    final call = _activeCall;
    if (call == null || !call.canEnableVideo) {
      return;
    }
    _isVideoEnabled = !_isVideoEnabled;
    await _signalingBridge.setVideoEnabled(_isVideoEnabled);
    _client.send({
      '@type': 'toggleGroupCallIsMyVideoEnabled',
      'group_call_id': call.id,
      'is_my_video_enabled': _isVideoEnabled,
    });
    notifyListeners();
  }

  void loadParticipants({int limit = 100}) {
    final call = _activeCall;
    if (call == null || call.id == 0) {
      return;
    }
    _client.send({
      '@type': 'getGroupCallParticipants',
      'input_group_call': {
        '@type': 'inputGroupCallMessage',
        'chat_id': call.chatId ?? 0,
        'message_id': 0,
      },
      'limit': limit,
    });
  }

  void _handleUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case 'groupCallId':
        _handleGroupCallId(update);
      case 'groupCallInfo':
        _handleGroupCallInfo(update);
      case 'groupCall':
        _handleGroupCall(update);
      case 'groupCallParticipants':
        _handleParticipants(update);
      case 'updateGroupCall':
        _handleGroupCallUpdate(update);
      case 'updateGroupCallParticipant':
        _handleParticipantUpdate(update);
      case 'text':
        _handleJoinResponse(update);
      case 'error':
        _handleError(update);
    }
  }

  void _handleGroupCallId(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('createVideoChat_')) {
      return;
    }
    final groupCallId = TdlibGroupCallParser.parseGroupCallId(update);
    if (groupCallId == null) {
      return;
    }
    _activeCall = (_activeCall ??
            GroupCallSummary(id: groupCallId, title: 'Video chat'))
        .copyWith(id: groupCallId);
    unawaited(
      joinActiveGroupCall(groupCallId: groupCallId, isVideo: _isVideoEnabled),
    );
  }

  void _handleGroupCallInfo(Map<String, dynamic> update) {
    final groupCallId = TdlibGroupCallParser.parseGroupCallId(update);
    if (groupCallId == null) {
      return;
    }
    _activeCall = (_activeCall ??
            GroupCallSummary(id: groupCallId, title: 'Групповой звонок'))
        .copyWith(id: groupCallId, phase: GroupCallUiPhase.joining);
    unawaited(
      joinActiveGroupCall(groupCallId: groupCallId, isVideo: _isVideoEnabled),
    );
  }

  void _handleGroupCall(Map<String, dynamic> update) {
    final parsed = TdlibGroupCallParser.parseGroupCall(
      update,
      chatId: _activeCall?.chatId,
      phase: _activeCall?.phase == GroupCallUiPhase.joining
          ? GroupCallUiPhase.active
          : _activeCall?.phase,
    );
    if (parsed == null) {
      return;
    }

    _activeCall = parsed.copyWith(
      phase: parsed.isJoined ? GroupCallUiPhase.active : parsed.phase,
    );

    if (parsed.isJoined && _platformCallUuid == null) {
      _platformCallUuid = 'group-${parsed.id}';
      unawaited(
        CallPlatformService.startActiveCall(
          callUuid: _platformCallUuid!,
          handle: parsed.title,
          title: parsed.title,
          isVideo: _isVideoEnabled,
          isIncoming: false,
        ),
      );
    }
    notifyListeners();
  }

  void _handleParticipants(Map<String, dynamic> update) {
    final ids = (update['participant_ids'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>();
    _participants
      ..clear()
      ..addAll(
        ids.map(
          (id) => GroupCallParticipantSummary(
            userId: switch (id['@type']) {
              'messageSenderUser' => id['user_id'] as int? ?? 0,
              _ => 0,
            },
          ),
        ),
      );
    notifyListeners();
  }

  void _handleGroupCallUpdate(Map<String, dynamic> update) {
    final raw = update['group_call'] as Map<String, dynamic>?;
    _handleGroupCall(raw ?? update);
  }

  void _handleParticipantUpdate(Map<String, dynamic> update) {
    final callId = update['group_call_id'] as int?;
    if (_activeCall?.id != callId) {
      return;
    }
    final participant = TdlibGroupCallParser.parseParticipant(
      update['participant'] as Map<String, dynamic>?,
    );
    if (participant == null) {
      return;
    }

    final index =
        _participants.indexWhere((item) => item.userId == participant.userId);
    if (index >= 0) {
      _participants[index] = participant;
    } else {
      _participants.add(participant);
    }
    notifyListeners();
  }

  void _handleJoinResponse(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null ||
        (!extra.startsWith('joinVideoChat_') && extra != 'createGroupCall')) {
      return;
    }
    final payload = TdlibGroupCallParser.parseJoinResponseText(update);
    if (payload == null) {
      return;
    }
    unawaited(_signalingBridge.applyGroupJoinResponse(payload));
    _client.send({
      '@type': 'getGroupCall',
      'group_call_id': _activeCall?.id ?? 0,
    });
  }

  void _handleError(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null) {
      return;
    }
    if (!extra.startsWith('createVideoChat_') &&
        !extra.startsWith('joinVideoChat_') &&
        extra != 'createGroupCall') {
      return;
    }
    _lastError = update['message'] as String? ?? 'Ошибка группового звонка';
    _activeCall = _activeCall?.copyWith(phase: GroupCallUiPhase.ended);
    notifyListeners();
  }

  Future<void> _stopPlatformCall() async {
    final uuid = _platformCallUuid;
    _platformCallUuid = null;
    if (uuid != null) {
      await CallPlatformService.endActiveCall(callUuid: uuid);
    }
  }

  void _resetState() {
    _activeCall = null;
    _participants.clear();
    _isMuted = false;
    _isVideoEnabled = false;
  }
}
