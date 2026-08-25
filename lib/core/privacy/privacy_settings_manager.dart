import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/privacy_settings_models.dart';
import '../tdlib/tdlib_client.dart';
import 'tdlib_privacy_parser.dart';

/// Настройки приватности аккаунта через TDLib.
class PrivacySettingsManager extends ChangeNotifier {
  PrivacySettingsManager({required TdlibClient client}) : _client = client;

  final TdlibClient _client;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  final Map<PrivacySettingKind, PrivacyRulesModel> _rulesBySetting = {};
  var _isLoading = false;
  var _isSaving = false;
  String? _lastError;

  Map<PrivacySettingKind, PrivacyRulesModel> get rulesBySetting =>
      Map.unmodifiable(_rulesBySetting);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get lastError => _lastError;

  static const List<PrivacySettingKind> supportedSettings = [
    PrivacySettingKind.showPhoneNumber,
    PrivacySettingKind.showProfilePhoto,
    PrivacySettingKind.showStatus,
    PrivacySettingKind.allowChatInvites,
    PrivacySettingKind.allowCalls,
    PrivacySettingKind.allowFindingByPhoneNumber,
  ];

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
    loadAll();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void loadAll() {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    for (final setting in supportedSettings) {
      _client.send({
        '@type': 'getUserPrivacySettingRules',
        'setting': setting.toTdlib(),
        '@extra': 'privacy_${setting.name}',
      });
    }
  }

  PrivacyRulePreset presetFor(PrivacySettingKind setting) {
    final rules = _rulesBySetting[setting];
    if (rules == null) {
      return PrivacyRulePreset.everybody;
    }
    return rules.detectPreset(
      allowMode: TdlibPrivacyParser.usesAllowMode(setting),
    );
  }

  void setPreset(PrivacySettingKind setting, PrivacyRulePreset preset) {
    _isSaving = true;
    _lastError = null;
    notifyListeners();

    final allowMode = TdlibPrivacyParser.usesAllowMode(setting);
    final rules = PrivacyRulesModel(
      rules: preset.toTdlibRules(allowMode: allowMode),
    );
    _client.send({
      '@type': 'setUserPrivacySettingRules',
      'setting': setting.toTdlib(),
      'rules': rules.toTdlib(),
      '@extra': 'privacy_set_${setting.name}',
    });
  }

  void _handleUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case 'userPrivacySettingRules':
        _handleRulesResponse(update);
      case 'updateUserPrivacySettingRules':
        _handleRulesUpdate(update);
      case 'ok':
        _handleOk(update);
      case 'error':
        _handleError(update);
    }
  }

  void _handleRulesResponse(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('privacy_') || extra.startsWith('privacy_set_')) {
      return;
    }
    final settingName = extra.substring('privacy_'.length);
    final setting = PrivacySettingKind.values.cast<PrivacySettingKind?>().firstWhere(
          (item) => item?.name == settingName,
          orElse: () => null,
        );
    if (setting == null) {
      return;
    }

    _rulesBySetting[setting] = TdlibPrivacyParser.parseRules(update);
    _isLoading = _rulesBySetting.length < supportedSettings.length;
    notifyListeners();
  }

  void _handleRulesUpdate(Map<String, dynamic> update) {
    final setting = TdlibPrivacyParser.parseSetting(
      update['setting'] as Map<String, dynamic>?,
    );
    final rules = update['rules'] as Map<String, dynamic>?;
    if (setting == null || rules == null) {
      return;
    }
    _rulesBySetting[setting] = TdlibPrivacyParser.parseRules(rules);
    notifyListeners();
  }

  void _handleOk(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('privacy_set_')) {
      return;
    }
    _isSaving = false;
    notifyListeners();
  }

  void _handleError(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('privacy_')) {
      return;
    }
    _isSaving = false;
    _isLoading = false;
    _lastError = update['message'] as String? ?? 'Ошибка настроек приватности';
    notifyListeners();
  }
}
