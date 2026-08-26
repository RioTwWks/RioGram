import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/auth/auth_state_predicates.dart';

void main() {
  group('auth_state_predicates', () {
    test('detects waitTdlibParameters stage', () {
      expect(
        isTdlibParametersStageUpdate({
          '@type': 'updateAuthorizationState',
          'authorization_state': {
            '@type': 'authorizationStateWaitTdlibParameters',
          },
        }),
        isTrue,
      );
    });

    test('detects past-parameters interactive stages', () {
      for (final state in [
        'authorizationStateWaitPhoneNumber',
        'authorizationStateReady',
      ]) {
        expect(
          isTdlibParametersStageUpdate({
            '@type': 'updateAuthorizationState',
            'authorization_state': {'@type': state},
          }),
          isTrue,
          reason: state,
        );
        expect(
          isInteractiveAuthorizationUpdate({
            '@type': 'updateAuthorizationState',
            'authorization_state': {'@type': state},
          }),
          isTrue,
          reason: state,
        );
      }
    });

    test('ignores unrelated updates', () {
      expect(
        isTdlibParametersStageUpdate({
          '@type': 'updateNewMessage',
        }),
        isFalse,
      );
    });
  });
}
