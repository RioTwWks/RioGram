import 'package:flutter_test/flutter_test.dart';

import 'package:riogram/models/external_integration_models.dart';

void main() {
  group('ExternalIntegrationsSettings', () {
    test('roundtrip json', () {
      const settings = ExternalIntegrationsSettings(
        autopostTarget: AutopostTarget(
          chatId: -10042,
          title: 'Мой канал',
          enabled: true,
        ),
        mirrorOutgoingText: false,
      );

      final restored = ExternalIntegrationsSettings.fromJson(settings.toJson());
      expect(restored.autopostTarget.chatId, -10042);
      expect(restored.autopostTarget.title, 'Мой канал');
      expect(restored.autopostTarget.enabled, isTrue);
      expect(restored.mirrorOutgoingText, isFalse);
    });
  });
}
