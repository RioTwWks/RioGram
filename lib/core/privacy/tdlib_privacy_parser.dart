import '../../models/privacy_settings_models.dart';

/// Парсинг TDLib-ответов для настроек приватности.
class TdlibPrivacyParser {
  static PrivacyRulesModel parseRules(Map<String, dynamic> json) {
    return PrivacySettingsJson.parseRules(json);
  }

  static PrivacySettingKind? parseSetting(Map<String, dynamic>? json) {
    return PrivacySettingKindX.fromTdlib(json);
  }

  static bool usesAllowMode(PrivacySettingKind kind) {
    return switch (kind) {
      PrivacySettingKind.showPhoneNumber ||
      PrivacySettingKind.showProfilePhoto ||
      PrivacySettingKind.showStatus =>
        true,
      PrivacySettingKind.allowChatInvites ||
      PrivacySettingKind.allowCalls ||
      PrivacySettingKind.allowFindingByPhoneNumber =>
        false,
    };
  }
}
