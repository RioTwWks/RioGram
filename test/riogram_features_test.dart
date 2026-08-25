import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/features/riogram_features_preferences.dart';
import 'package:riogram/models/anti_recall_models.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RioGramFeaturesPreferences', () {
    test('сохраняет настройки призрачного режима и медиа', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = RioGramFeaturesPreferences();

      await preferences.setGhostModeEnabled(true);
      await preferences.setHideTypingStatus(false);
      await preferences.setAntiRecallEnabled(true);
      await preferences.setDefaultVideoSpeed(1.5);
      await preferences.setTranslatorTargetLanguage('en');

      expect(preferences.ghostModeEnabled, isTrue);
      expect(preferences.hideTypingStatus, isFalse);
      expect(preferences.antiRecallEnabled, isTrue);
      expect(preferences.defaultVideoSpeedValue, 1.5);
      expect(preferences.translatorTargetLanguage, 'en');
    });
  });

  group('AntiRecallSnapshot', () {
    test('сериализуется и десериализуется', () {
      final message = ChatMessage(
        id: 42,
        chatId: 7,
        content: const MessageContent(
          kind: MessageKind.text,
          preview: 'Секретное сообщение',
        ),
        date: DateTime(2026, 1, 1),
        isOutgoing: false,
      );

      final snapshot = AntiRecallSnapshot.fromMessage(
        message,
        reason: AntiRecallSnapshotReason.edited,
        capturedAt: DateTime(2026, 1, 2),
      );

      final restored = AntiRecallSnapshot.fromJson(snapshot.toJson());
      expect(restored.messageId, 42);
      expect(restored.chatId, 7);
      expect(restored.content.preview, 'Секретное сообщение');
      expect(restored.reason, AntiRecallSnapshotReason.edited);
    });
  });
}
