import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/wss_proxy_models.dart';

/// Локальные настройки WSS-прокси (Web-платформа).
class WebSocketProxyPreferences {
  static const _configKey = 'riogram_wss_proxy_config';

  Future<WssProxyConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configKey);
    if (raw == null || raw.isEmpty) {
      return const WssProxyConfig();
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return WssProxyConfig.fromJson(decoded);
    } catch (_) {
      return const WssProxyConfig();
    }
  }

  Future<void> save(WssProxyConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
  }
}
