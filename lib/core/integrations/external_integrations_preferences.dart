import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/external_integration_models.dart';

/// Хранение настроек внешних интеграций.
class ExternalIntegrationsPreferences {
  ExternalIntegrationsPreferences(this._preferences);

  final SharedPreferences _preferences;

  static const _settingsKey = 'external_integrations_settings_v1';

  ExternalIntegrationsSettings load() {
    final raw = _preferences.getString(_settingsKey);
    if (raw == null || raw.isEmpty) {
      return const ExternalIntegrationsSettings();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ExternalIntegrationsSettings.fromJson(decoded);
      }
    } catch (_) {
      return const ExternalIntegrationsSettings();
    }
    return const ExternalIntegrationsSettings();
  }

  Future<void> save(ExternalIntegrationsSettings settings) async {
    await _preferences.setString(
      _settingsKey,
      jsonEncode(settings.toJson()),
    );
  }
}
