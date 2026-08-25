import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/notifications/tdlib_notification_parser.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:riogram/models/notification_settings_models.dart';

void main() {
  group('NotificationSettingsJson', () {
    test('parseScope reads mute and preview', () {
      final settings = NotificationSettingsJson.parseScope({
        '@type': 'scopeNotificationSettings',
        'mute_for': 3600,
        'show_preview': false,
        'disable_mention_notifications': true,
        'disable_pinned_message_notifications': false,
      });

      expect(settings.isMuted, isTrue);
      expect(settings.showPreview, isFalse);
      expect(settings.disableMentionNotifications, isTrue);
    });

    test('parseChat respects default flags', () {
      final settings = NotificationSettingsJson.parseChat({
        '@type': 'chatNotificationSettings',
        'use_default_mute_for': false,
        'mute_for': 7200,
        'use_default_show_preview': false,
        'show_preview': true,
        'use_default_sound': true,
        'sound_id': 0,
      });

      expect(settings.isMuted(), isTrue);
      expect(settings.effectiveShowPreview(), isTrue);
    });

    test('parseDefaultAutoDeleteSeconds reads messageAutoDeleteTime', () {
      expect(
        NotificationSettingsJson.parseDefaultAutoDeleteSeconds({
          '@type': 'messageAutoDeleteTime',
          'time': 86400,
        }),
        86400,
      );
    });
  });

  group('TdlibNotificationParser', () {
    test('scopeForChatKind maps channel and group', () {
      expect(
        TdlibNotificationParser.scopeForChatKind(ChatKind.channel),
        NotificationScopeKind.channelChats,
      );
      expect(
        TdlibNotificationParser.scopeForChatKind(ChatKind.group),
        NotificationScopeKind.groupChats,
      );
    });

    test('isChatMuted detects explicit mute', () {
      expect(
        TdlibNotificationParser.isChatMuted({
          'use_default_mute_for': false,
          'mute_for': 100,
        }),
        isTrue,
      );
      expect(
        TdlibNotificationParser.isChatMuted({
          'use_default_mute_for': true,
          'mute_for': 100,
        }),
        isFalse,
      );
    });
  });

  group('AutoDeletePreset', () {
    test('fromSeconds maps week', () {
      expect(
        AutoDeletePresetX.fromSeconds(604800),
        AutoDeletePreset.oneWeek,
      );
    });
  });
}
