import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../models/call_media_models.dart';
import '../../../models/call_models.dart';
import '../../tdlib/tdlib_json.dart';

/// WebRTC/tgcalls медиа-слой: захват A/V, ICE, passthrough сигналинга TDLib.
class WebRtcMediaEngine {
  WebRtcMediaEngine();

  final _stateController = StreamController<CallMediaState>.broadcast();
  Stream<CallMediaState> get mediaStateStream => _stateController.stream;

  void Function(List<int> data)? onOutboundSignaling;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;
  CallMediaState _state = const CallMediaState();
  var _renderersInitialized = false;
  var _audioSourceId = 0;
  String _groupJoinPayload = '';
  final List<List<int>> _pendingSignaling = [];

  int get audioSourceId => _audioSourceId;
  String get groupJoinPayload => _groupJoinPayload;

  Future<void> initializeRenderers() async {
    if (_renderersInitialized) {
      return;
    }
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersInitialized = true;
  }

  Future<void> startCall({
    required CallReadyPayload payload,
    required bool isVideo,
  }) async {
    await initializeRenderers();
    await stopCall();

    _audioSourceId = _generateAudioSourceId();
    _groupJoinPayload = '';

    final constraints = <String, dynamic>{
      'audio': {
        'mandatory': {},
        'optional': [
          {'googNoiseSuppression': true},
          {'googEchoCancellation': true},
        ],
      },
      'video': isVideo
          ? {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    localRenderer.srcObject = _localStream;

    final configuration = _buildPeerConfiguration(payload);
    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
        _emitState(
          _state.copyWith(
            hasRemoteAudio: true,
            hasRemoteVideo: event.track.kind == 'video' || isVideo,
          ),
        );
      }
    };

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate == null) {
        return;
      }
      final encoded = _encodeIceCandidate(candidate);
      onOutboundSignaling?.call(encoded);
    };

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    _emitState(
      _state.copyWith(
        hasLocalAudio: _localStream!.getAudioTracks().isNotEmpty,
        hasLocalVideo: _localStream!.getVideoTracks().isNotEmpty,
      ),
    );

    for (final chunk in _pendingSignaling) {
      await handleSignalingData(chunk);
    }
    _pendingSignaling.clear();
  }

  Future<GroupCallJoinParams> buildGroupCallJoinParams({
    bool isMuted = false,
    bool isVideo = false,
  }) async {
    await initializeRenderers();

    if (_localStream == null) {
      final constraints = <String, dynamic>{
        'audio': true,
        'video': isVideo,
      };
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      localRenderer.srcObject = _localStream;
      _audioSourceId = _generateAudioSourceId();
    }

    if (_groupJoinPayload.isEmpty) {
      _groupJoinPayload = _buildGroupPayloadPlaceholder();
    }

    return GroupCallJoinParams(
      audioSourceId: _audioSourceId,
      payload: _groupJoinPayload,
      isMuted: isMuted,
      isMyVideoEnabled: isVideo,
    );
  }

  Future<void> applyGroupJoinResponse(String payload) async {
    _groupJoinPayload = payload;
    if (payload.isNotEmpty) {
      await handleSignalingData(payload.codeUnits);
    }
  }

  Future<void> handleSignalingData(List<int> data) async {
    if (data.isEmpty) {
      return;
    }

    if (_peerConnection == null) {
      _pendingSignaling.add(data);
      return;
    }

    final message = String.fromCharCodes(data);
    if (message.startsWith('{')) {
      try {
        if (message.contains('"type":"offer"') ||
            message.contains('"type":"answer"')) {
          await _handleSdpMessage(message);
          return;
        }
        if (message.contains('"type":"candidate"')) {
          await _handleCandidateMessage(message);
          return;
        }
      } catch (_) {
        // tgcalls binary payload — сохраняем для будущего native FFI.
      }
    }

    _pendingSignaling.add(data);
  }

  Future<void> setMuted(bool muted) async {
    for (final track in _localStream?.getAudioTracks() ?? const []) {
      track.enabled = !muted;
    }
    _emitState(_state.copyWith(isMuted: muted));
  }

  Future<void> setVideoEnabled(bool enabled) async {
    for (final track in _localStream?.getVideoTracks() ?? const []) {
      track.enabled = enabled;
    }
    _emitState(_state.copyWith(hasLocalVideo: enabled));
  }

  Future<List<CallAudioDevice>> listAudioDevices() async {
    final devices = await navigator.mediaDevices.enumerateDevices();
    return devices
        .where(
          (device) =>
              device.kind == 'audioinput' || device.kind == 'audiooutput',
        )
        .map(
          (device) => CallAudioDevice(
            id: device.deviceId,
            label: device.label.isNotEmpty ? device.label : device.deviceId,
            kind: device.kind == 'audioinput'
                ? CallAudioDeviceKind.input
                : CallAudioDeviceKind.output,
          ),
        )
        .toList();
  }

  Future<void> selectAudioInput(String deviceId) async {
    if (_localStream == null) {
      return;
    }

    final constraints = <String, dynamic>{
      'audio': {'deviceId': deviceId},
      'video': _localStream!.getVideoTracks().isNotEmpty,
    };

    final newStream = await navigator.mediaDevices.getUserMedia(constraints);
    final newAudio = newStream.getAudioTracks();
    if (newAudio.isEmpty) {
      await newStream.dispose();
      return;
    }

    for (final track in _localStream!.getAudioTracks()) {
      await _localStream!.removeTrack(track);
      await track.stop();
    }
    await _localStream!.addTrack(newAudio.first);

    final senders = await _peerConnection?.getSenders() ?? [];
    for (final sender in senders) {
      if (sender.track?.kind == 'audio') {
        await sender.replaceTrack(newAudio.first);
      }
    }

    _emitState(_state.copyWith(selectedInputDeviceId: deviceId));
  }

  Future<void> selectAudioOutput(String deviceId) async {
    if (kIsWeb) {
      return;
    }
    try {
      await Helper.selectAudioOutput(deviceId);
      _emitState(_state.copyWith(selectedOutputDeviceId: deviceId));
    } catch (_) {
      // Output routing may be unavailable on some platforms.
    }
  }

  Future<void> stopCall() async {
    for (final track in _localStream?.getTracks() ?? const []) {
      await track.stop();
    }
    await _localStream?.dispose();
    _localStream = null;
    localRenderer.srcObject = null;

    await _peerConnection?.close();
    _peerConnection = null;
    remoteRenderer.srcObject = null;

    _pendingSignaling.clear();
    _groupJoinPayload = '';
    _emitState(const CallMediaState());
  }

  Future<void> dispose() async {
    await stopCall();
    await _stateController.close();
    if (_renderersInitialized) {
      await localRenderer.dispose();
      await remoteRenderer.dispose();
    }
  }

  Map<String, dynamic> _buildPeerConfiguration(CallReadyPayload payload) {
    final iceServers = <Map<String, dynamic>>[];
    for (final server in payload.servers) {
      final host = server['ip_address'] as String? ?? '';
      final port = tdIntOr(server['port']);
      if (host.isEmpty || port <= 0) {
        continue;
      }
      iceServers.add({
        'urls': 'stun:$host:$port',
      });
    }
    if (iceServers.isEmpty) {
      iceServers.add({'urls': 'stun:stun.l.google.com:19302'});
    }
    return {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    };
  }

  Future<void> _handleSdpMessage(String message) async {
    final pc = _peerConnection;
    if (pc == null) {
      return;
    }
    if (message.contains('"type":"offer"')) {
      await pc.setRemoteDescription(
        RTCSessionDescription(_extractSdp(message), 'offer'),
      );
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      onOutboundSignaling?.call(answer.sdp?.codeUnits ?? const []);
      return;
    }
    if (message.contains('"type":"answer"')) {
      await pc.setRemoteDescription(
        RTCSessionDescription(_extractSdp(message), 'answer'),
      );
    }
  }

  Future<void> _handleCandidateMessage(String message) async {
    final pc = _peerConnection;
    if (pc == null) {
      return;
    }
    final candidate = _extractCandidate(message);
    if (candidate == null) {
      return;
    }
    await pc.addCandidate(candidate);
  }

  String _extractSdp(String message) {
    final start = message.indexOf('"sdp":"');
    if (start < 0) {
      return message;
    }
    final from = start + 7;
    final end = message.indexOf('"', from);
    if (end < 0) {
      return message.substring(from);
    }
    return message.substring(from, end).replaceAll(r'\n', '\n');
  }

  RTCIceCandidate? _extractCandidate(String message) {
    final candidateStart = message.indexOf('"candidate":"');
    if (candidateStart < 0) {
      return null;
    }
    final from = candidateStart + 13;
    final to = message.indexOf('"', from);
    final candidate = to < 0
        ? message.substring(from)
        : message.substring(from, to);
    final sdpMid = _extractJsonString(message, 'sdpMid') ?? '';
    final sdpMLineIndex =
        int.tryParse(_extractJsonString(message, 'sdpMLineIndex') ?? '0') ?? 0;
    return RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
  }

  String? _extractJsonString(String message, String key) {
    final token = '"$key":"';
    final start = message.indexOf(token);
    if (start < 0) {
      return null;
    }
    final from = start + token.length;
    final end = message.indexOf('"', from);
    if (end < 0) {
      return null;
    }
    return message.substring(from, end);
  }

  List<int> _encodeIceCandidate(RTCIceCandidate candidate) {
    final payload =
        '{"type":"candidate","candidate":"${candidate.candidate}","sdpMid":"${candidate.sdpMid}","sdpMLineIndex":${candidate.sdpMLineIndex}}';
    return payload.codeUnits;
  }

  String _buildGroupPayloadPlaceholder() {
    return '{"version":1,"audio_source_id":$_audioSourceId}';
  }

  int _generateAudioSourceId() {
    final random = Random();
    return random.nextInt(0x7FFFFFFF);
  }

  void _emitState(CallMediaState state) {
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }
}
