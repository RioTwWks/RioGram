import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/call/call_signaling_bridge.dart';
import 'package:riogram/core/call/tdlib_group_call_parser.dart';
import 'package:riogram/models/call_media_models.dart';
import 'package:riogram/models/group_call_models.dart';

void main() {
  group('StubCallSignalingBridge group join params', () {
    test('buildGroupCallJoinParams returns tdlib payload', () async {
      final bridge = StubCallSignalingBridge();
      final params = await bridge.buildGroupCallJoinParams(
        isMuted: true,
        isVideo: true,
      );
      final tdlib = params.toTdlib();
      expect(tdlib['@type'], 'groupCallJoinParameters');
      expect(tdlib['is_muted'], isTrue);
      expect(tdlib['is_my_video_enabled'], isTrue);
    });
  });

  group('TdlibGroupCallParser', () {
    test('parseGroupCall', () {
      final call = TdlibGroupCallParser.parseGroupCall({
        '@type': 'groupCall',
        'id': 42,
        'title': 'Team sync',
        'is_video_chat': true,
        'is_joined': true,
        'is_active': true,
        'participant_count': 5,
        'can_enable_video': true,
      });
      expect(call, isNotNull);
      expect(call!.id, 42);
      expect(call.title, 'Team sync');
      expect(call.participantCount, 5);
    });

    test('parseParticipant user', () {
      final participant = TdlibGroupCallParser.parseParticipant({
        '@type': 'groupCallParticipant',
        'participant_id': {
          '@type': 'messageSenderUser',
          'user_id': 100,
        },
        'is_current_user': true,
        'is_speaking': true,
      });
      expect(participant!.userId, 100);
      expect(participant.isCurrentUser, isTrue);
      expect(participant.isSpeaking, isTrue);
    });

    test('parseGroupCallId from groupCallInfo', () {
      expect(
        TdlibGroupCallParser.parseGroupCallId({
          '@type': 'groupCallInfo',
          'group_call_id': 7,
        }),
        7,
      );
    });
  });

  group('GroupCallSummary', () {
    test('hasActiveCall when joining or active', () {
      expect(
        const GroupCallSummary(
          id: 1,
          title: 'x',
          phase: GroupCallUiPhase.joining,
        ).hasActiveCall,
        isTrue,
      );
      expect(
        const GroupCallSummary(
          id: 1,
          title: 'x',
          phase: GroupCallUiPhase.idle,
        ).hasActiveCall,
        isFalse,
      );
    });
  });

  group('CallAudioDevice', () {
    test('equality by id and kind', () {
      const a = CallAudioDevice(
        id: 'default',
        label: 'Default',
        kind: CallAudioDeviceKind.input,
      );
      const b = CallAudioDevice(
        id: 'default',
        label: 'Other label',
        kind: CallAudioDeviceKind.input,
      );
      expect(a, equals(b));
    });
  });
}
