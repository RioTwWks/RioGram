import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/call_media_models.dart';
import '../../models/call_models.dart';
import '../tdlib/tdlib_client.dart';
import 'call_platform_service.dart';
import 'call_signaling_bridge.dart';
import 'tdlib_call_parser.dart';
import '../tdlib/tdlib_json.dart';

/// Управление 1:1 звонками через TDLib (`createCall`, `acceptCall`, `discardCall`).
class CallManager extends ChangeNotifier {
  CallManager({
    required TdlibClient client,
    CallSignalingBridge? signalingBridge,
  })  : _client = client,
        _signalingBridge = signalingBridge ?? StubCallSignalingBridge() {
    _signalingBridge.setOutboundSignalingHandler(sendSignalingData);
  }

  final TdlibClient _client;
  final CallSignalingBridge _signalingBridge;

  StreamSubscription<Map<String, dynamic>>? _subscription;
  StreamSubscription<CallMediaState>? _mediaSubscription;
  final Map<int, UserCallCapabilities> _userCapabilities = {};
  final Map<int, String> _userDisplayNames = {};

  CallSummary? _activeCall;
  DateTime? _connectedAt;
  Timer? _durationTimer;
  Duration _callDuration = Duration.zero;
  var _isMuted = false;
  var _isVideoEnabled = false;
  String? _lastError;
  String? _platformCallUuid;
  CallMediaState _mediaState = const CallMediaState();

  CallSignalingBridge get signalingBridge => _signalingBridge;

  CallSummary? get activeCall => _activeCall;
  Duration get callDuration => _callDuration;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  CallMediaState get mediaState => _mediaState;
  bool get hasActiveCall =>
      _activeCall != null && _activeCall!.uiPhase != CallUiPhase.idle;
  bool get hasIncomingCall => _activeCall?.isIncomingRinging ?? false;
  String? get lastError => _lastError;

  UserCallCapabilities capabilitiesFor(int userId) =>
      _userCapabilities[userId] ?? UserCallCapabilities.none;

  String displayNameFor(int userId) =>
      _userDisplayNames[userId] ?? 'Пользователь';

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
    _mediaSubscription ??=
        _signalingBridge.mediaStateStream.listen((state) {
      _mediaState = state;
      _isMuted = state.isMuted;
      notifyListeners();
    });

    CallPlatformService.installHandler(
      onAccept: (_) => unawaited(acceptCall()),
      onDecline: (_) => unawaited(declineCall()),
      onEnd: (_) => unawaited(hangUp()),
    );
  }

  Future<List<CallAudioDevice>> listAudioDevices() =>
      _signalingBridge.listAudioDevices();

  Future<void> selectAudioInput(String deviceId) =>
      _signalingBridge.selectAudioInput(deviceId);

  Future<void> selectAudioOutput(String deviceId) =>
      _signalingBridge.selectAudioOutput(deviceId);

  @override
  void dispose() {
    _durationTimer?.cancel();
    _subscription?.cancel();
    _mediaSubscription?.cancel();
    super.dispose();
  }

  void loadUserCallCapabilities(int userId) {
    if (_userCapabilities.containsKey(userId)) {
      return;
    }
    _client.send({
      '@type': 'getUserFullInfo',
      'user_id': userId,
      '@extra': 'callUserFullInfo_$userId',
    });
    _requestUserName(userId);
  }

  Future<void> startOutgoingCall({
    required int userId,
    required bool isVideo,
    String? displayName,
  }) async {
    if (_activeCall != null && !_activeCall!.isEnded) {
      _lastError = 'Уже есть активный звонок';
      notifyListeners();
      return;
    }

    _lastError = null;
    if (displayName != null && displayName.isNotEmpty) {
      _userDisplayNames[userId] = displayName;
    }
    loadUserCallCapabilities(userId);

    _client.send({
      '@type': 'createCall',
      'user_id': userId,
      'protocol': TdlibCallParser.defaultCallProtocol(),
      'is_video': isVideo,
      '@extra': 'createCall_$userId',
    });
  }

  Future<void> acceptCall() async {
    final call = _activeCall;
    if (call == null || !call.isIncomingRinging) {
      return;
    }
    _client.send({
      '@type': 'acceptCall',
      'call_id': call.id,
      'protocol': TdlibCallParser.defaultCallProtocol(),
      '@extra': 'acceptCall_${call.id}',
    });
  }

  Future<void> declineCall() async {
    await _discardActiveCall(isDisconnected: false);
  }

  Future<void> hangUp() async {
    await _discardActiveCall(isDisconnected: false);
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _signalingBridge.setMuted(_isMuted);
    notifyListeners();
  }

  Future<void> toggleVideo() async {
    final call = _activeCall;
    if (call == null || !call.isVideo) {
      return;
    }
    _isVideoEnabled = !_isVideoEnabled;
    await _signalingBridge.setVideoEnabled(_isVideoEnabled);
    notifyListeners();
  }

  void _handleUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case 'updateCall':
        _handleCallUpdate(update['call'] as Map<String, dynamic>);
      case 'updateNewCallSignalingData':
        _handleNewSignalingData(update);
      case 'userFullInfo':
        _handleUserFullInfo(update);
      case 'user':
        _handleUser(update);
      case 'error':
        _handleError(update);
    }
  }

  void _handleCallUpdate(Map<String, dynamic> raw) {
    final parsed = TdlibCallParser.parseCall(raw);
    if (parsed == null || parsed.id == 0) {
      return;
    }

    final previous = _activeCall;
    final displayName = _userDisplayNames[parsed.userId];
    _activeCall = parsed.copyWith(userDisplayName: displayName);
    _isVideoEnabled = parsed.isVideo;

    if (parsed.isIncomingRinging && _platformCallUuid == null) {
      _platformCallUuid = 'call-${parsed.id}';
      unawaited(
        CallPlatformService.reportIncomingCall(
          callUuid: _platformCallUuid!,
          handle: displayName ?? displayNameFor(parsed.userId),
          title: parsed.isVideo ? 'Видеозвонок' : 'Звонок',
          isVideo: parsed.isVideo,
        ),
      );
    }

    final stateRaw = raw['state'] as Map<String, dynamic>? ?? {};
    switch (parsed.stateKind) {
      case CallStateKind.ready:
        _onCallReady(stateRaw, parsed);
      case CallStateKind.discarded:
      case CallStateKind.error:
        _onCallEnded(parsed);
      case CallStateKind.pending:
      case CallStateKind.exchangingKeys:
      case CallStateKind.hangingUp:
        if (parsed.stateKind == CallStateKind.exchangingKeys) {
          _stopDurationTimer();
        }
      case CallStateKind.unknown:
        break;
    }

    if (previous?.id != parsed.id ||
        previous?.stateKind != parsed.stateKind ||
        previous?.uiPhase != parsed.uiPhase) {
      notifyListeners();
    }
  }

  Future<void> _onCallReady(
    Map<String, dynamic> stateRaw,
    CallSummary call,
  ) async {
    final payload = TdlibCallParser.parseCallReadyPayload(stateRaw);
    if (payload == null) {
      return;
    }
    _connectedAt ??= DateTime.now();
    _startDurationTimer();

    _platformCallUuid ??= 'call-${call.id}';
    final name = call.userDisplayName ?? displayNameFor(call.userId);
    await CallPlatformService.startActiveCall(
      callUuid: _platformCallUuid!,
      handle: name,
      title: call.isVideo ? 'Видеозвонок' : 'Звонок',
      isVideo: call.isVideo,
      isIncoming: !call.isOutgoing,
    );
    await CallPlatformService.setCallConnected(callUuid: _platformCallUuid!);

    await _signalingBridge.onCallReady(
      callId: call.id,
      payload: payload,
      isVideo: call.isVideo,
    );
  }

  Future<void> _onCallEnded(CallSummary call) async {
    await _signalingBridge.onCallEnded();
    if (_platformCallUuid != null) {
      await CallPlatformService.endActiveCall(callUuid: _platformCallUuid!);
      _platformCallUuid = null;
    }
    _stopDurationTimer();
    _connectedAt = null;
    _isMuted = false;
    _isVideoEnabled = false;
    _mediaState = const CallMediaState();

    Future<void>.delayed(const Duration(seconds: 2), () {
      if (_activeCall?.id == call.id && _activeCall!.isEnded) {
        _activeCall = null;
        notifyListeners();
      }
    });
  }

  void _handleNewSignalingData(Map<String, dynamic> update) {
    final callId = tdInt(update['call_id']);
    final dataRaw = update['data'];
    if (callId == null || _activeCall?.id != callId) {
      return;
    }

    final data = _bytesFromDynamic(dataRaw);
    if (data.isEmpty) {
      return;
    }

    unawaited(_signalingBridge.onSignalingData(data));
  }

  void sendSignalingData(List<int> data) {
    final callId = _activeCall?.id;
    if (callId == null || data.isEmpty) {
      return;
    }
    _client.send({
      '@type': 'sendCallSignalingData',
      'call_id': callId,
      'data': data,
    });
  }

  void _handleUserFullInfo(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('callUserFullInfo_')) {
      return;
    }
    final userId = int.tryParse(extra.substring('callUserFullInfo_'.length));
    if (userId == null) {
      return;
    }
    _userCapabilities[userId] =
        TdlibCallParser.parseUserCallCapabilities(update);
    notifyListeners();
  }

  void _handleUser(Map<String, dynamic> user) {
    final userId = tdInt(user['id']);
    if (userId == null) {
      return;
    }
    final firstName = user['first_name'] as String? ?? '';
    final lastName = user['last_name'] as String? ?? '';
    final displayName = '$firstName $lastName'.trim();
    if (displayName.isNotEmpty) {
      _userDisplayNames[userId] = displayName;
      if (_activeCall?.userId == userId) {
        _activeCall = _activeCall!.copyWith(userDisplayName: displayName);
        notifyListeners();
      }
    }
  }

  void _handleError(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null ||
        (!extra.startsWith('createCall_') && !extra.startsWith('acceptCall_'))) {
      return;
    }
    _lastError = update['message'] as String? ?? 'Ошибка звонка';
    notifyListeners();
  }

  Future<void> _discardActiveCall({required bool isDisconnected}) async {
    final call = _activeCall;
    if (call == null) {
      return;
    }

    final duration = _connectedAt == null
        ? 0
        : DateTime.now().difference(_connectedAt!).inSeconds;

    _client.send({
      '@type': 'discardCall',
      'call_id': call.id,
      'is_disconnected': isDisconnected,
      'invite_link': '',
      'duration': duration,
      'is_video': call.isVideo,
      'connection_id': 0,
    });
  }

  void _requestUserName(int userId) {
    if (_userDisplayNames.containsKey(userId)) {
      return;
    }
    _client.send({
      '@type': 'getUser',
      'user_id': userId,
    });
  }

  void _startDurationTimer() {
    _durationTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (_connectedAt == null) {
        return;
      }
      _callDuration = DateTime.now().difference(_connectedAt!);
      notifyListeners();
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _callDuration = Duration.zero;
  }

  static List<int> _bytesFromDynamic(dynamic value) {
    if (value is List) {
      return value.whereType<int>().toList();
    }
    if (value is String) {
      return value.codeUnits;
    }
    return const [];
  }
}
