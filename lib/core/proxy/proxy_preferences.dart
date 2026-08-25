import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/proxy_models.dart';

/// Настройки прокси, сохраняемые локально.
class ProxyPreferences {
  static const _autoFailoverKey = 'proxy_auto_failover_enabled';
  static const _userProxiesKey = 'proxy_user_configs';

  Future<bool> isAutoFailoverEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoFailoverKey) ?? true;
  }

  Future<void> setAutoFailoverEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoFailoverKey, enabled);
  }

  Future<List<UserProxyConfig>> loadUserProxies() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userProxiesKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(UserProxyConfig.fromJson)
          .whereType<UserProxyConfig>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveUserProxies(List<UserProxyConfig> proxies) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(proxies.map((item) => item.toJson()).toList());
    await prefs.setString(_userProxiesKey, encoded);
  }

  Future<void> addUserProxy(UserProxyConfig proxy) async {
    final current = await loadUserProxies();
    final updated = [
      ...current.where((item) => item.id != proxy.id),
      proxy,
    ];
    await saveUserProxies(updated);
  }
}
