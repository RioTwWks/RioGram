import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/proxy_models.dart';
import '../config/app_config.dart';
import '../tdlib/tdlib_client.dart';
import 'proxy_preferences.dart';

export '../../models/proxy_models.dart' show ProxyEntry, ProxyHealth;

enum ProxyStatus { unknown, active, switching, error, disabled }

/// Управление прокси PhantomProxy / StealthGate с автоматическим failover.
class ProxyManager extends ChangeNotifier {
  ProxyManager({
    required TdlibClient client,
    required AppConfig config,
    ProxyPreferences? preferences,
  })  : _client = client,
        _config = config,
        _preferences = preferences ?? ProxyPreferences() {
    _updatesSubscription = _client.updates.listen(_handleUpdate);
  }

  final TdlibClient _client;
  final AppConfig _config;
  final ProxyPreferences _preferences;

  static const Duration pingTimeout = Duration(seconds: 5);
  static const Duration healthCheckInterval = Duration(seconds: 30);

  final List<ProxyEntry> _proxies = [];
  final List<ProxyConfig> _pendingConfigs = [];

  StreamSubscription<Map<String, dynamic>>? _updatesSubscription;
  Timer? _healthTimer;

  ProxyStatus _status = ProxyStatus.unknown;
  bool _autoFailoverEnabled = true;
  String? _lastError;

  List<ProxyEntry> get proxies => List.unmodifiable(_proxies);
  ProxyStatus get status => _status;
  bool get autoFailoverEnabled => _autoFailoverEnabled;
  String? get lastError => _lastError;

  ProxyEntry? get activeProxy {
    for (final proxy in _proxies) {
      if (proxy.isActive) {
        return proxy;
      }
    }
    return null;
  }

  String? get activeProxyName => activeProxy?.name;

  /// Загрузка настроек и регистрация прокси в TDLib.
  Future<void> setupProxies() async {
    _autoFailoverEnabled = await _preferences.isAutoFailoverEnabled();
    _proxies.clear();
    _pendingConfigs.clear();
    _lastError = null;

    final configs = [
      _config.phantomProxy,
      _config.stealthProxy,
    ].whereType<ProxyConfig>().where((proxy) => proxy.isConfigured).toList();

    if (configs.isEmpty) {
      _status = ProxyStatus.disabled;
      notifyListeners();
      return;
    }

    _status = ProxyStatus.unknown;
    _pendingConfigs.addAll(configs);
    notifyListeners();

    for (final proxy in configs) {
      _client.send({
        '@type': 'addProxy',
        'server': proxy.host,
        'port': proxy.port,
        'enable': false,
        'type': {
          '@type': 'proxyTypeMtproto',
          'secret': proxy.secret,
        },
      });
    }

    await _waitForProxyRegistration(configs.length);
    await _enableFirstAvailable();
    _startHealthChecks();
  }

  Future<void> setAutoFailoverEnabled(bool enabled) async {
    _autoFailoverEnabled = enabled;
    await _preferences.setAutoFailoverEnabled(enabled);
    notifyListeners();
  }

  /// Ручное переключение на конкретный прокси.
  Future<bool> activateProxy(int proxyId) async {
    final index = _proxies.indexWhere((proxy) => proxy.id == proxyId);
    if (index < 0) {
      return false;
    }

    _setProxyHealth(proxyId, ProxyHealth.checking);
    _status = ProxyStatus.switching;
    notifyListeners();

    final isHealthy = await pingProxy(proxyId);
    if (!isHealthy) {
      _setProxyHealth(proxyId, ProxyHealth.failed);
      _status = ProxyStatus.error;
      _lastError = 'Прокси ${_proxies[index].name} не отвечает';
      notifyListeners();
      return false;
    }

    _client.send({'@type': 'enableProxy', 'proxy_id': proxyId});
    _setActiveProxy(proxyId);
    _status = ProxyStatus.active;
    _lastError = null;
    notifyListeners();
    return true;
  }

  /// Проверка конкретного прокси (кнопка «Тест» в настройках).
  Future<bool> testProxy(int proxyId) async {
    _setProxyHealth(proxyId, ProxyHealth.checking);
    notifyListeners();

    final isHealthy = await pingProxy(proxyId);
    _setProxyHealth(proxyId, isHealthy ? ProxyHealth.ok : ProxyHealth.failed);
    notifyListeners();
    return isHealthy;
  }

  /// Переключение на следующий рабочий прокси.
  Future<void> switchToNextProxy() async {
    if (_proxies.isEmpty || !_autoFailoverEnabled) {
      return;
    }

    _status = ProxyStatus.switching;
    notifyListeners();

    final currentIndex = _proxies.indexWhere((proxy) => proxy.isActive);
    final startIndex = currentIndex < 0 ? 0 : currentIndex + 1;

    for (var offset = 0; offset < _proxies.length; offset++) {
      final index = (startIndex + offset) % _proxies.length;
      final proxy = _proxies[index];
      if (proxy.isActive) {
        continue;
      }

      final isHealthy = await pingProxy(proxy.id);
      if (isHealthy) {
        _client.send({'@type': 'enableProxy', 'proxy_id': proxy.id});
        _setActiveProxy(proxy.id);
        _status = ProxyStatus.active;
        _lastError = null;
        notifyListeners();
        return;
      }
      _setProxyHealth(proxy.id, ProxyHealth.failed);
    }

    _status = ProxyStatus.error;
    _lastError = 'Все прокси недоступны';
    notifyListeners();
  }

  /// Вызывается при проблемах с соединением (из AuthManager).
  Future<void> handleConnectionIssue() async {
    if (!_autoFailoverEnabled || _proxies.isEmpty) {
      return;
    }
    await switchToNextProxy();
  }

  Future<bool> pingProxy(int proxyId) async {
    final responseFuture = _client.waitFor(
      predicate: (update) {
        final type = update['@type'];
        if (type == 'error') {
          return true;
        }
        if (type == 'ok' && update['@extra'] == 'ping_$proxyId') {
          return true;
        }
        return false;
      },
      timeout: pingTimeout,
    );

    _client.send({
      '@type': 'pingProxy',
      'proxy_id': proxyId,
      '@extra': 'ping_$proxyId',
    });

    final response = await responseFuture;
    if (response == null || response['@type'] == 'error') {
      _setProxyHealth(proxyId, ProxyHealth.failed);
      return false;
    }

    _setProxyHealth(proxyId, ProxyHealth.ok);
    return true;
  }

  void _handleUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case 'proxy':
        _registerProxy(update);
      case 'updateProxy':
        final proxyId = update['proxy_id'] as int?;
        if (proxyId != null) {
          _setActiveProxy(proxyId);
          _status = ProxyStatus.active;
          notifyListeners();
        }
      case 'updateConnectionState':
        _handleConnectionState(update['state'] as Map<String, dynamic>?);
    }
  }

  void _handleConnectionState(Map<String, dynamic>? state) {
    if (state == null || !_autoFailoverEnabled) {
      return;
    }

    final type = state['@type'];
    if (type == 'connectionStateWaitingForNetwork') {
      unawaited(switchToNextProxy());
    }
  }

  void _registerProxy(Map<String, dynamic> proxy) {
    final id = proxy['id'] as int?;
    if (id == null || _pendingConfigs.isEmpty) {
      return;
    }

    final config = _pendingConfigs.removeAt(0);
    _proxies.add(
      ProxyEntry(
        id: id,
        name: config.name,
        host: config.host,
        port: config.port,
      ),
    );
    notifyListeners();
  }

  Future<void> _waitForProxyRegistration(int expectedCount) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (_proxies.length < expectedCount && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _enableFirstAvailable() async {
    if (_proxies.isEmpty) {
      _status = ProxyStatus.error;
      _lastError = 'Прокси не зарегистрированы в TDLib';
      notifyListeners();
      return;
    }

    for (final proxy in _proxies) {
      final isHealthy = await pingProxy(proxy.id);
      if (isHealthy) {
        _client.send({'@type': 'enableProxy', 'proxy_id': proxy.id});
        _setActiveProxy(proxy.id);
        _status = ProxyStatus.active;
        _lastError = null;
        notifyListeners();
        return;
      }
      _setProxyHealth(proxy.id, ProxyHealth.failed);
    }

    _status = ProxyStatus.error;
    _lastError = 'Нет доступных прокси при старте';
    notifyListeners();
  }

  void _setActiveProxy(int proxyId) {
    for (var i = 0; i < _proxies.length; i++) {
      _proxies[i] = _proxies[i].copyWith(isActive: _proxies[i].id == proxyId);
    }
  }

  void _setProxyHealth(int proxyId, ProxyHealth health) {
    final index = _proxies.indexWhere((proxy) => proxy.id == proxyId);
    if (index >= 0) {
      _proxies[index] = _proxies[index].copyWith(health: health);
    }
  }

  void _startHealthChecks() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(healthCheckInterval, (_) async {
      if (!_autoFailoverEnabled) {
        return;
      }
      final active = activeProxy;
      if (active == null) {
        return;
      }
      final isHealthy = await pingProxy(active.id);
      if (!isHealthy) {
        await switchToNextProxy();
      }
    });
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _updatesSubscription?.cancel();
    super.dispose();
  }
}
