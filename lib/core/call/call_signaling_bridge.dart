import '../../models/call_models.dart';

/// Мост между TDLib-сигналингом и медиа-движком (tgcalls/WebRTC).
abstract class CallSignalingBridge {
  const CallSignalingBridge();

  Future<void> onCallReady({
    required int callId,
    required CallReadyPayload payload,
    required bool isVideo,
  });

  Future<void> onSignalingData(List<int> data);

  Future<void> onCallEnded();

  /// Локальное включение/выключение видео (UI + будущий tgcalls).
  Future<void> setVideoEnabled(bool enabled);
}

/// Заглушка: сохраняет состояние, пока tgcalls/WebRTC не подключены.
class StubCallSignalingBridge extends CallSignalingBridge {
  StubCallSignalingBridge();

  CallReadyPayload? lastReadyPayload;
  var videoEnabled = false;
  final List<List<int>> receivedSignaling = [];

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
    receivedSignaling.clear();
  }

  @override
  Future<void> setVideoEnabled(bool enabled) async {
    videoEnabled = enabled;
  }
}
