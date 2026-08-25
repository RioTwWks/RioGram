import '../../models/notification_settings_models.dart';
import '../../models/chat_models.dart';
import '../tdlib/tdlib_json.dart';

/// Парсинг TDLib-ответов для настроек уведомлений.
class TdlibNotificationParser {
  static ScopeNotificationSettingsModel parseScopeNotificationSettings(
    Map<String, dynamic> json,
  ) {
    return NotificationSettingsJson.parseScope(json);
  }

  static ChatNotificationSettingsModel parseChatNotificationSettings(
    Map<String, dynamic> json,
  ) {
    return NotificationSettingsJson.parseChat(json);
  }

  static NotificationScopeKind? parseScopeKind(Map<String, dynamic>? json) {
    return NotificationScopeKindX.fromTdlib(json);
  }

  static bool isChatMuted(Map<String, dynamic>? settings) {
    if (settings == null) {
      return false;
    }
    if (settings['use_default_mute_for'] as bool? ?? true) {
      return false;
    }
    return tdIntOr(settings['mute_for']) > 0;
  }

  static NotificationScopeKind scopeForChatKind(ChatKind kind) {
    return switch (kind) {
      ChatKind.channel => NotificationScopeKind.channelChats,
      ChatKind.group => NotificationScopeKind.groupChats,
      _ => NotificationScopeKind.privateChats,
    };
  }
}
