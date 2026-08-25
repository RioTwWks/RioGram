import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/secret/tdlib_secret_parser.dart';
import 'package:riogram/models/secret_chat_models.dart';

void main() {
  group('SecretChatJson', () {
    test('parseSecretChat maps ready state and key hash', () {
      final summary = TdlibSecretParser.parseSecretChat({
        '@type': 'secretChat',
        'id': 42,
        'user_id': 100,
        'state': {'@type': 'secretChatStateReady'},
        'is_outbound': true,
        'key_hash': 'abcd',
        'layer': 144,
      });

      expect(summary.id, 42);
      expect(summary.userId, 100);
      expect(summary.state, SecretChatStateKind.ready);
      expect(summary.keyHash, isNotEmpty);
    });
  });

  group('SecretChatTtlPreset', () {
    test('toSelfDestructType returns timer payload', () {
      expect(
        SecretChatTtlPreset.oneMinute.toSelfDestructType(),
        {
          '@type': 'messageSelfDestructTypeTimer',
          'self_destruct_time': 60,
        },
      );
      expect(SecretChatTtlPreset.off.toSelfDestructType(), isNull);
    });
  });
}
