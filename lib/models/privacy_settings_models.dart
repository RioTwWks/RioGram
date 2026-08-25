/// Настройки приватности TDLib, используемые в §6.9.
enum PrivacySettingKind {
  showPhoneNumber,
  showProfilePhoto,
  showStatus,
  allowChatInvites,
  allowCalls,
  allowFindingByPhoneNumber,
}

extension PrivacySettingKindX on PrivacySettingKind {
  Map<String, dynamic> toTdlib() {
    return switch (this) {
      PrivacySettingKind.showPhoneNumber => {
          '@type': 'userPrivacySettingShowPhoneNumber',
        },
      PrivacySettingKind.showProfilePhoto => {
          '@type': 'userPrivacySettingShowProfilePhoto',
        },
      PrivacySettingKind.showStatus => {
          '@type': 'userPrivacySettingShowStatus',
        },
      PrivacySettingKind.allowChatInvites => {
          '@type': 'userPrivacySettingAllowChatInvites',
        },
      PrivacySettingKind.allowCalls => {
          '@type': 'userPrivacySettingAllowCalls',
        },
      PrivacySettingKind.allowFindingByPhoneNumber => {
          '@type': 'userPrivacySettingAllowFindingByPhoneNumber',
        },
    };
  }

  String get label => switch (this) {
        PrivacySettingKind.showPhoneNumber => 'Номер телефона',
        PrivacySettingKind.showProfilePhoto => 'Фото профиля',
        PrivacySettingKind.showStatus => 'Был(а) в сети',
        PrivacySettingKind.allowChatInvites => 'Добавление в группы',
        PrivacySettingKind.allowCalls => 'Звонки',
        PrivacySettingKind.allowFindingByPhoneNumber => 'Поиск по номеру',
      };

  static PrivacySettingKind? fromTdlib(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return switch (json['@type']) {
      'userPrivacySettingShowPhoneNumber' =>
        PrivacySettingKind.showPhoneNumber,
      'userPrivacySettingShowProfilePhoto' =>
        PrivacySettingKind.showProfilePhoto,
      'userPrivacySettingShowStatus' => PrivacySettingKind.showStatus,
      'userPrivacySettingAllowChatInvites' =>
        PrivacySettingKind.allowChatInvites,
      'userPrivacySettingAllowCalls' => PrivacySettingKind.allowCalls,
      'userPrivacySettingAllowFindingByPhoneNumber' =>
        PrivacySettingKind.allowFindingByPhoneNumber,
      _ => null,
    };
  }
}

/// Упрощённый пресет правил приватности для UI.
enum PrivacyRulePreset {
  everybody,
  contacts,
  nobody,
}

extension PrivacyRulePresetX on PrivacyRulePreset {
  String get label => switch (this) {
        PrivacyRulePreset.everybody => 'Все',
        PrivacyRulePreset.contacts => 'Контакты',
        PrivacyRulePreset.nobody => 'Никто',
      };

  List<Map<String, dynamic>> toTdlibRules({required bool allowMode}) {
    return switch (this) {
      PrivacyRulePreset.everybody => [
          {'@type': 'userPrivacySettingRuleAllowAll'},
        ],
      PrivacyRulePreset.contacts => [
          {'@type': 'userPrivacySettingRuleAllowContacts'},
        ],
      PrivacyRulePreset.nobody => [
          {'@type': 'userPrivacySettingRuleRestrictAll'},
        ],
    };
  }
}

/// Правила приватности для одной настройки.
class PrivacyRulesModel {
  const PrivacyRulesModel({required this.rules});

  final List<Map<String, dynamic>> rules;

  PrivacyRulePreset detectPreset({required bool allowMode}) {
    final types = rules.map((rule) => rule['@type'] as String?).toSet();
    if (types.contains('userPrivacySettingRuleAllowAll')) {
      return PrivacyRulePreset.everybody;
    }
    if (types.contains('userPrivacySettingRuleAllowContacts')) {
      return PrivacyRulePreset.contacts;
    }
    return PrivacyRulePreset.nobody;
  }

  Map<String, dynamic> toTdlib() {
    return {
      '@type': 'userPrivacySettingRules',
      'rules': rules,
    };
  }
}

/// Парсинг правил приватности TDLib.
class PrivacySettingsJson {
  static PrivacyRulesModel parseRules(Map<String, dynamic> json) {
    final raw = json['rules'] as List<dynamic>? ?? const [];
    return PrivacyRulesModel(
      rules: raw.whereType<Map<String, dynamic>>().toList(growable: false),
    );
  }
}
