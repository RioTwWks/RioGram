import 'package:shared_preferences/shared_preferences.dart';

/// Настройки прокси, сохраняемые локально.
class ProxyPreferences {
  static const _autoFailoverKey = 'proxy_auto_failover_enabled';

  Future<bool> isAutoFailoverEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoFailoverKey) ?? true;
  }

  Future<void> setAutoFailoverEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoFailoverKey, enabled);
  }
}
