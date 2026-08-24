/// Тип аудиоустройства для VoIP.
enum CallAudioDeviceKind {
  input,
  output,
}

/// Аудиоустройство ввода/вывода.
class CallAudioDevice {
  const CallAudioDevice({
    required this.id,
    required this.label,
    required this.kind,
  });

  final String id;
  final String label;
  final CallAudioDeviceKind kind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallAudioDevice &&
          id == other.id &&
          kind == other.kind;

  @override
  int get hashCode => Object.hash(id, kind);
}

/// Параметры подключения к групповому звонку (TDLib `groupCallJoinParameters`).
class GroupCallJoinParams {
  const GroupCallJoinParams({
    required this.audioSourceId,
    required this.payload,
    this.isMuted = false,
    this.isMyVideoEnabled = false,
  });

  final int audioSourceId;
  final String payload;
  final bool isMuted;
  final bool isMyVideoEnabled;

  Map<String, dynamic> toTdlib() => {
        '@type': 'groupCallJoinParameters',
        'audio_source_id': audioSourceId,
        'payload': payload,
        'is_muted': isMuted,
        'is_my_video_enabled': isMyVideoEnabled,
      };
}

/// Состояние медиа-потока звонка.
class CallMediaState {
  const CallMediaState({
    this.hasLocalAudio = false,
    this.hasLocalVideo = false,
    this.hasRemoteAudio = false,
    this.hasRemoteVideo = false,
    this.isMuted = false,
    this.selectedInputDeviceId,
    this.selectedOutputDeviceId,
  });

  final bool hasLocalAudio;
  final bool hasLocalVideo;
  final bool hasRemoteAudio;
  final bool hasRemoteVideo;
  final bool isMuted;
  final String? selectedInputDeviceId;
  final String? selectedOutputDeviceId;

  CallMediaState copyWith({
    bool? hasLocalAudio,
    bool? hasLocalVideo,
    bool? hasRemoteAudio,
    bool? hasRemoteVideo,
    bool? isMuted,
    String? selectedInputDeviceId,
    String? selectedOutputDeviceId,
  }) {
    return CallMediaState(
      hasLocalAudio: hasLocalAudio ?? this.hasLocalAudio,
      hasLocalVideo: hasLocalVideo ?? this.hasLocalVideo,
      hasRemoteAudio: hasRemoteAudio ?? this.hasRemoteAudio,
      hasRemoteVideo: hasRemoteVideo ?? this.hasRemoteVideo,
      isMuted: isMuted ?? this.isMuted,
      selectedInputDeviceId:
          selectedInputDeviceId ?? this.selectedInputDeviceId,
      selectedOutputDeviceId:
          selectedOutputDeviceId ?? this.selectedOutputDeviceId,
    );
  }
}
