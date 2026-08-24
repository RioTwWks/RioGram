import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/call/tdlib_call_parser.dart';
import 'package:riogram/models/call_models.dart';

void main() {
  group('TdlibCallParser', () {
    test('defaultCallProtocol содержит tgcalls versions', () {
      final protocol = TdlibCallParser.defaultCallProtocol();
      expect(protocol['@type'], 'callProtocol');
      expect(protocol['library_versions'], ['2.6', '3.0']);
    });

    test('parseCall — входящий pending', () {
      final call = TdlibCallParser.parseCall({
        '@type': 'call',
        'id': 10,
        'user_id': 42,
        'is_outgoing': false,
        'is_video': false,
        'state': {
          '@type': 'callStatePending',
          'is_created': true,
          'is_received': true,
        },
      });

      expect(call, isNotNull);
      expect(call!.id, 10);
      expect(call.userId, 42);
      expect(call.isIncomingRinging, isTrue);
      expect(call.uiPhase, CallUiPhase.incomingRinging);
    });

    test('parseCall — active ready', () {
      final call = TdlibCallParser.parseCall({
        '@type': 'call',
        'id': 11,
        'user_id': 1,
        'is_outgoing': true,
        'is_video': true,
        'state': {
          '@type': 'callStateReady',
          'config': '{}',
          'encryption_key': [1, 2, 3],
          'custom_parameters': '{}',
          'allow_p2p': true,
          'servers': [],
        },
      });

      expect(call!.stateKind, CallStateKind.ready);
      expect(call.isActive, isTrue);
      expect(call.isVideo, isTrue);
    });

    test('parseUserCallCapabilities', () {
      final caps = TdlibCallParser.parseUserCallCapabilities({
        '@type': 'userFullInfo',
        'can_be_called': true,
        'supports_video_calls': true,
      });
      expect(caps.canBeCalled, isTrue);
      expect(caps.supportsVideoCalls, isTrue);
    });

    test('parseCallMessage missed incoming', () {
      final info = CallMessageInfo.fromTdlib(
        {
          '@type': 'messageCall',
          'is_video': false,
          'duration': 0,
          'discard_reason': {'@type': 'callDiscardReasonMissed'},
        },
        isOutgoing: false,
      );
      expect(info.isMissed, isTrue);
      expect(info.preview(isOutgoing: false), 'Пропущенный звонок');
    });

    test('parseCallMessage completed video', () {
      final info = CallMessageInfo.fromTdlib(
        {
          '@type': 'messageCall',
          'is_video': true,
          'duration': 125,
          'discard_reason': {'@type': 'callDiscardReasonHungUp'},
        },
        isOutgoing: true,
      );
      expect(info.preview(isOutgoing: true), 'Видеозвонок (2:05)');
    });

    test('statusLabel для outgoing ringing', () {
      final call = CallSummary(
        id: 1,
        userId: 2,
        isOutgoing: true,
        isVideo: false,
        stateKind: CallStateKind.pending,
      );
      expect(TdlibCallParser.statusLabel(call), 'Вызов…');
    });
  });
}
