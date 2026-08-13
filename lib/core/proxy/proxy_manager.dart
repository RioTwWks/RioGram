import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/proxy_models.dart';
import '../config/app_config.dart';
import '../tdlib/tdlib_client.dart';
import 'proxy_preferences.dart';
import 'system_proxy_config.dart';
import 'system_proxy_detector.dart';

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

  static const Duration pingTimeout = Duration(seconds: 20);
  static const Duration healthCheckInterval = Duration(seconds: 30);

  final List<ProxyEntry> _proxies = [];
  final List<ProxyConfig> _pendingConfigs = [];
  final Map<int, ProxyConfig> _configsById = {};

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

  SystemProxyConfig? get systemProxy => _systemProxy;

  bool get hasActiveProxy => activeProxy != null && _status == ProxyStatus.active;

  SystemProxyConfig? _systemProxy;

  /// Загрузка настроек и регистрация прокси в TDLib.
  Future<void> setupProxies() async {
    _autoFailoverEnabled = await _preferences.isAutoFailoverEnabled();
    _proxies.clear();
    _pendingConfigs.clear();
    _configsById.clear();
    _systemProxy = null;
    _lastError = null;

    _systemProxy = await SystemProxyDetector.detect();
    final systemProxy = _systemProxy;
    var expectedRegistrations = 0;

    final configs = [
      _config.phantomProxy,
      _config.stealthProxy,
    ].whereType<ProxyConfig>().where((proxy) => proxy.host.isNotEmpty).toList();

    final validConfigs =
        configs.where((proxy) => proxy.hasValidSecret).toList(growable: false);
    final invalidNames = configs
        .where((proxy) => !proxy.hasValidSecret)
        .map((proxy) => proxy.name)
        .toList(growable: false);

    if (invalidNames.isNotEmpty) {
      _lastError =
          'Неверный secret у: ${invalidNames.join(', ')}. '
          'Для Fake TLS (ee...) после 32 hex-символов нужен домен, '
          'например google.com в hex: 676f6f676c652e636f6d';
    }

    if (systemProxy != null && systemProxy.isConfigured) {
      expectedRegistrations++;
      final isTransportOnly = validConfigs.isNotEmpty;
      _client.send({
        '@type': 'addProxy',
        'proxy': _systemProxyPayload(systemProxy),
        'enable': false,
        'comment': isTransportOnly
            ? SystemProxyConfig.transportComment
            : 'Системный прокси',
        '@extra': isTransportOnly ? 'addProxy_Transport' : 'addProxy_System',
      });
    }

    if (validConfigs.isEmpty) {
      if (systemProxy == null || !systemProxy.isConfigured) {
        _status = ProxyStatus.error;
        if (_lastError == null) {
          _lastError = 'Нет прокси с корректным secret в .env и системный прокси не найден';
        }
        notifyListeners();
        return;
      }

      _status = ProxyStatus.unknown;
      notifyListeners();
      await _waitForProxyRegistration(expectedRegistrations);
      await _enableSystemProxyOnly();
      _startHealthChecks();
      return;
    }

    _status = ProxyStatus.unknown;
    _pendingConfigs.addAll(validConfigs);
    expectedRegistrations += validConfigs.length;
    notifyListeners();

    for (final proxy in validConfigs) {
      _client.send({
        '@type': 'addProxy',
        'proxy': _proxyPayload(proxy),
        'enable': false,
        'comment': proxy.name,
        '@extra': 'addProxy_${proxy.name}',
      });
    }

    await _waitForProxyRegistration(expectedRegistrations);
    await _enableFirstAvailable();
    _startHealthChecks();
  }

  Future<void> _enableSystemProxyOnly() async {
    final systemEntry = _proxies.cast<ProxyEntry?>().firstWhere(
          (proxy) => proxy?.name == 'Системный прокси',
          orElse: () => null,
        );
    if (systemEntry == null) {
      _status = ProxyStatus.error;
      _lastError ??= 'Системный прокси не зарегистрирован в TDLib';
      notifyListeners();
      return;
    }
    await _enableProxy(systemEntry.id);
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

    final ping = await pingProxy(proxyId);
    if (!ping.ok) {
      // Включаем всё равно: ping через Fake TLS иногда ложно падает,
      // а рабочий прокси всё равно нужен для авторизации.
      debugPrint('ProxyManager: ping ${ _proxies[index].name} failed: ${ping.error}');
    }

    await _enableProxy(proxyId);
    return true;
  }

  /// Проверка конкретного прокси (кнопка «Тест» в настройках).
  Future<bool> testProxy(int proxyId) async {
    _setProxyHealth(proxyId, ProxyHealth.checking);
    notifyListeners();

    final ping = await pingProxy(proxyId);
    _setProxyHealth(proxyId, ping.ok ? ProxyHealth.ok : ProxyHealth.failed);
    if (!ping.ok) {
      _lastError = ping.error;
    }
    notifyListeners();
    return ping.ok;
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

      final ping = await pingProxy(proxy.id);
      if (ping.ok) {
        await _enableProxy(proxy.id);
        return;
      }
      _setProxyHealth(proxy.id, ProxyHealth.failed);
    }

    // Если ни один ping не прошёл — всё равно пробуем следующий по кругу.
    if (_proxies.isNotEmpty) {
      final fallback = _proxies[startIndex % _proxies.length];
      await _enableProxy(fallback.id);
      _lastError = 'Ping не подтвердил доступность, включён ${fallback.name}';
      notifyListeners();
      return;
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

  Future<({bool ok, String? error})> pingProxy(int proxyId) async {
    final config = _configsById[proxyId];
    if (config == null) {
      return (ok: false, error: 'Прокси $proxyId не найден в локальном кэше');
    }

    final extra = 'ping_$proxyId';
    final responseFuture = _client.waitFor(
      predicate: (update) {
        if (update['@extra'] != extra) {
          return false;
        }
        final type = update['@type'];
        return type == 'seconds' || type == 'error';
      },
      timeout: pingTimeout,
    );

    _client.send({
      '@type': 'pingProxy',
      'proxy': _proxyPayload(config),
      '@extra': extra,
    });

    final response = await responseFuture;
    if (response == null) {
      _setProxyHealth(proxyId, ProxyHealth.failed);
      return (
        ok: false,
        error: 'Таймаут ping ${config.name} (${pingTimeout.inSeconds}с)',
      );
    }
    if (response['@type'] == 'error') {
      _setProxyHealth(proxyId, ProxyHealth.failed);
      final message = response['message'] as String? ?? 'неизвестная ошибка';
      return (ok: false, error: '${config.name}: $message');
    }

    _setProxyHealth(proxyId, ProxyHealth.ok);
    return (ok: true, error: null);
  }

  void _handleUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case 'addedProxy':
        _registerAddedProxy(update);
      case 'error':
        _handleProxyError(update);
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

  void _registerAddedProxy(Map<String, dynamic> addedProxy) {
    final id = addedProxy['id'] as int?;
    if (id == null) {
      return;
    }

    final extra = addedProxy['@extra'] as String?;
    ProxyConfig? config;
    String? displayName;
    if (extra == 'addProxy_System') {
      displayName = 'Системный прокси';
    } else if (extra == 'addProxy_Transport') {
      displayName = 'Системный прокси (транспорт)';
    } else if (extra != null && extra.startsWith('addProxy_')) {
      final name = extra.substring('addProxy_'.length);
      final index = _pendingConfigs.indexWhere((item) => item.name == name);
      if (index >= 0) {
        config = _pendingConfigs.removeAt(index);
        displayName = config.name;
      }
    } else if (_pendingConfigs.isNotEmpty) {
      config = _pendingConfigs.removeAt(0);
      displayName = config.name;
    }

    if (displayName == null) {
      return;
    }

    if (config != null) {
      _configsById[id] = config;
    }
    _proxies.add(
      ProxyEntry(
        id: id,
        name: displayName,
        host: config?.host ?? _systemProxy?.host ?? '',
        port: config?.port ?? _systemProxy?.port ?? 0,
      ),
    );
    notifyListeners();
  }

  void _handleProxyError(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('addProxy_')) {
      return;
    }

    final name = extra.substring('addProxy_'.length);
    _pendingConfigs.removeWhere((item) => item.name == name);
    final message = update['message'] as String? ?? 'ошибка регистрации';
    _lastError = '$name: $message';
    notifyListeners();
  }

  Map<String, dynamic> _proxyPayload(ProxyConfig proxy) {
    return {
      '@type': 'proxy',
      'server': proxy.host,
      'port': proxy.port,
      'type': {
        '@type': 'proxyTypeMtproto',
        'secret': proxy.secret,
      },
    };
  }

  Map<String, dynamic> _systemProxyPayload(SystemProxyConfig proxy) {
    return {
      '@type': 'proxy',
      'server': proxy.host,
      'port': proxy.port,
      'type': proxy.type == SystemProxyType.socks5
          ? {
              '@type': 'proxyTypeSocks5',
              'username': proxy.username,
              'password': proxy.password,
            }
          : {
              '@type': 'proxyTypeHttp',
              'username': proxy.username,
              'password': proxy.password,
              'http_only': false,
            },
    };
  }

  Future<void> _waitForProxyRegistration(int expectedCount) async {
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (_proxies.length < expectedCount && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _enableFirstAvailable() async {
    if (_proxies.isEmpty) {
      _status = ProxyStatus.error;
      _lastError ??= 'Прокси не зарегистрированы в TDLib';
      notifyListeners();
      return;
    }

    final mtprotoProxies = _proxies
        .where(
          (proxy) =>
              proxy.name != 'Системный прокси (транспорт)' &&
              proxy.name != 'Системный прокси',
        )
        .toList(growable: false);
    if (mtprotoProxies.isEmpty) {
      await _enableSystemProxyOnly();
      return;
    }

    // Сначала включаем первый MTProto-прокси — без этого авторизация в РФ зависает.
    final first = mtprotoProxies.first;
    await _enableProxy(first.id);

    final ping = await pingProxy(first.id);
    if (!ping.ok) {
      debugPrint('ProxyManager: стартовый ping ${first.name}: ${ping.error}');
      for (final proxy in mtprotoProxies.skip(1)) {
        final other = await pingProxy(proxy.id);
        if (other.ok) {
          await _enableProxy(proxy.id);
          return;
        }
        debugPrint('ProxyManager: ping ${proxy.name}: ${other.error}');
      }
      _lastError = ping.error ?? 'Ping прокси не подтвердил доступность';
      notifyListeners();
    }
  }

  Future<void> _enableProxy(int proxyId) async {
    final extra = 'enableProxy_$proxyId';
    final responseFuture = _client.waitFor(
      predicate: (update) {
        if (update['@extra'] != extra) {
          return false;
        }
        final type = update['@type'];
        return type == 'ok' || type == 'error';
      },
      timeout: const Duration(seconds: 5),
    );

    _client.send({
      '@type': 'enableProxy',
      'proxy_id': proxyId,
      '@extra': extra,
    });

    final response = await responseFuture;
    if (response == null || response['@type'] == 'error') {
      final message = response?['message'] as String? ?? 'таймаут enableProxy';
      _status = ProxyStatus.error;
      _lastError = 'Не удалось включить прокси: $message';
      notifyListeners();
      return;
    }

    _setActiveProxy(proxyId);
    _setProxyHealth(proxyId, ProxyHealth.ok);
    _status = ProxyStatus.active;
    _lastError = null;
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
      final ping = await pingProxy(active.id);
      if (!ping.ok) {
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
