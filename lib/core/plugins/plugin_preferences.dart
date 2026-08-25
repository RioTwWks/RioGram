import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/plugin_models.dart';

/// Хранение состояния плагинов.
class PluginPreferences {
  PluginPreferences(this._preferences);

  final SharedPreferences _preferences;

  static const _statesKey = 'plugin_user_states_v1';

  Map<String, PluginUserState> loadStates() {
    final raw = _preferences.getString(_statesKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return {};
      }
      return decoded.map(
        (key, value) => MapEntry(
          key,
          value is Map<String, dynamic>
              ? PluginUserState.fromJson(value)
              : const PluginUserState(enabled: false),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> saveStates(Map<String, PluginUserState> states) async {
    final encoded = states.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    await _preferences.setString(_statesKey, jsonEncode(encoded));
  }
}
