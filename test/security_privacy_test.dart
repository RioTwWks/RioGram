import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/privacy/ad_block_filter.dart';
import 'package:riogram/core/privacy/security_privacy_preferences.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:riogram/models/security_privacy_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecurityPrivacyPreferences', () {
    test('сохраняет настройки Local Premium и телеметрии', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = SecurityPrivacyPreferences();

      await preferences.setLocalPremiumEnabled(true);
      await preferences.setLocalPremiumUploadFileSize(true);
      await preferences.setBlockAdsEnabled(true);
      await preferences.setTelemetryMode(TelemetryMode.enabled);

      expect(preferences.localPremiumEnabled, isTrue);
      expect(preferences.localPremiumUploadFileSize, isTrue);
      expect(preferences.blockAdsEnabled, isTrue);
      expect(preferences.telemetryMode, TelemetryMode.enabled);
    });
  });

  group('AdBlockFilter', () {
    test('определяет спонсорский чат по источнику позиции', () {
      final chat = ChatSummary(
        id: 1,
        title: 'Реклама',
        positions: const [
          ChatPositionInfo(
            list: ChatListMain(),
            order: 1,
            isPinned: false,
            source: ChatPositionSource.sponsored,
          ),
        ],
      );

      expect(AdBlockFilter.isSponsoredChat(chat), isTrue);
      expect(AdBlockFilter.filterChats([chat]), isEmpty);
    });

    test('определяет спонсорское сообщение по id', () {
      const sponsoredId = AdBlockFilter.maxServerMessageId + 10;
      final message = ChatMessage(
        id: sponsoredId,
        chatId: 42,
        content: const MessageContent(
          kind: MessageKind.text,
          preview: 'Реклама',
        ),
        date: DateTime(2026, 1, 1),
        isOutgoing: false,
      );

      expect(AdBlockFilter.isSponsoredMessage(message), isTrue);
      expect(AdBlockFilter.filterMessages([message]), isEmpty);
    });
  });

  group('TelegramUploadLimits', () {
    test('лимиты 2 ГБ и 4 ГБ', () {
      expect(TelegramUploadLimits.freeMaxBytes, 2 * 1024 * 1024 * 1024);
      expect(TelegramUploadLimits.premiumMaxBytes, 4 * 1024 * 1024 * 1024);
    });
  });
}
