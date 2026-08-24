import '../../models/call_media_models.dart';
import '../../models/call_models.dart';
import 'media/webrtc_media_engine.dart';

/// Мост между TDLib-сигналингом и медиа-движком (tgcalls/WebRTC).
abstract class CallSignalingBridge {
  const CallSignalingBridge();

  void setOutboundSignalingHandler(void Function(List<int> data)? handler);

  Stream<CallMediaState> get mediaStateStream;

  WebRtcMediaEngine? get mediaEngine;

  Future<void> onCallReady({
    required int callId,
    required CallReadyPayload payload,
    required bool isVideo,
  });

  Future<void> onSignalingData(List<int> data);

  Future<void> onCallEnded();

  Future<void> setMuted(bool muted);

  Future<void> setVideoEnabled(bool enabled);

  Future<List<CallAudioDevice>> listAudioDevices();

  Future<void> selectAudioInput(String deviceId);

  Future<void> selectAudioOutput(String deviceId);

  Future<GroupCallJoinParams> buildGroupCallJoinParams({
    bool isMuted = false,
    bool isVideo = false,
  });

  Future<void> applyGroupJoinResponse(String payload);
}

/// Заглушка без WebRTC (тесты и fallback).
class StubCallSignalingBridge extends CallSignalingBridge {
  StubCallSignalingBridge();

  CallReadyPayload? lastReadyPayload;
  var videoEnabled = false;
  var muted = false;
  final List<List<int>> receivedSignaling = [];

  @override
  WebRtcMediaEngine? get mediaEngine => null;

  @override
  Stream<CallMediaState> get mediaStateStream =>
      const Stream<CallMediaState>.empty();

  @override
  void setOutboundSignalingHandler(void Function(List<int> data)? handler) {}

  @override
  Future<void> onCallReady({
    required int callId,
    required CallReadyPayload payload,
    required bool isVideo,
  }) async {
    lastReadyPayload = payload;
    videoEnabled = isVideo;
  }

  @override
  Future<void> onSignalingData(List<int> data) async {
    receivedSignaling.add(data);
  }

  @override
  Future<void> onCallEnded() async {
    lastReadyPayload = null;
    videoEnabled = false;
    muted = false;
    receivedSignaling.clear();
  }

  @override
  Future<void> setMuted(bool value) async {
    muted = value;
  }

  @override
  Future<void> setVideoEnabled(bool enabled) async {
    videoEnabled = enabled;
  }

  @override
  Future<List<CallAudioDevice>> listAudioDevices() async => const [];

  @override
  Future<void> selectAudioInput(String deviceId) async {}

  @override
  Future<void> selectAudioOutput(String deviceId) async {}

  @override
  Future<GroupCallJoinParams> buildGroupCallJoinParams({
    bool isMuted = false,
    bool isVideo = false,
  }) async {
    return GroupCallJoinParams(
      audioSourceId: 1,
      payload: '{}',
      isMuted: isMuted,
      isMyVideoEnabled: isVideo,
    );
  }

  @override
  Future<void> applyGroupJoinResponse(String payload) async {}
}

/// WebRTC-реализация с passthrough tgcalls-сигналинга через TDLib.
class WebRtcCallSignalingBridge extends CallSignalingBridge {
  WebRtcCallSignalingBridge({WebRtcMediaEngine? engine})
      : _engine = engine ?? WebRtcMediaEngine() {
    _engine.onOutboundSignaling = (data) => _outboundHandler?.call(data);
  }

  final WebRtcMediaEngine _engine;
  void Function(List<int> data)? _outboundHandler;

  @override
  WebRtcMediaEngine? get mediaEngine => _engine;

  @override
  Stream<CallMediaState> get mediaStateStream => _engine.mediaStateStream;

  @override
  void setOutboundSignalingHandler(void Function(List<int> data)? handler) {
    _outboundHandler = handler;
    _engine.onOutboundSignaling = (data) => _outboundHandler?.call(data);
  }

  @override
  Future<void> onCallReady({
    required int callId,
    required CallReadyPayload payload,
    required bool isVideo,
  }) async {
    await _engine.startCall(payload: payload, isVideo: isVideo);
  }

  @override
  Future<void> onSignalingData(List<int> data) async {
    await _engine.handleSignalingData(data);
  }

  @override
  Future<void> onCallEnded() async {
    await _engine.stopCall();
  }

  @override
  Future<void> setMuted(bool muted) async {
    await _engine.setMuted(muted);
  }

  @override
  Future<void> setVideoEnabled(bool enabled) async {
    await _engine.setVideoEnabled(enabled);
  }

  @override
  Future<List<CallAudioDevice>> listAudioDevices() =>
      _engine.listAudioDevices();

  @override
  Future<void> selectAudioInput(String deviceId) =>
      _engine.selectAudioInput(deviceId);

  @override
  Future<void> selectAudioOutput(String deviceId) =>
      _engine.selectAudioOutput(deviceId);

  @override
  Future<GroupCallJoinParams> buildGroupCallJoinParams({
    bool isMuted = false,
    bool isVideo = false,
  }) =>
      _engine.buildGroupCallJoinParams(isMuted: isMuted, isVideo: isVideo);

  @override
  Future<void> applyGroupJoinResponse(String payload) =>
      _engine.applyGroupJoinResponse(payload);
}
