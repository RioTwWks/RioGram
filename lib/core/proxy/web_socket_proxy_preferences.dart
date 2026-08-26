import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/wss_proxy_models.dart';

/// Локальные настройки WSS-прокси (Web-платформа).
class WebSocketProxyPreferences {
  static const _configKey = 'riogram_wss_proxy_config';

  Future<WssProxyConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configKey);
    if (raw == null || raw.isEmpty) {
      return _defaultFromEnv();
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return WssProxyConfig.fromJson(decoded);
    } catch (_) {
      return _defaultFromEnv();
    }
  }

  WssProxyConfig _defaultFromEnv() {
    final url = dotenv.maybeGet('WEB_WSS_PROXY_URL')?.trim() ?? '';
    if (url.isNotEmpty) {
      return WssProxyConfig(enabled: true, url: url);
    }
    if (kIsWeb) {
      final base = Uri.base;
      if (base.scheme == 'https' && base.host.isNotEmpty) {
        return WssProxyConfig(enabled: true, url: 'wss://${base.host}');
      }
    }
    return const WssProxyConfig();
  }

  Future<void> save(WssProxyConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
  }
}
