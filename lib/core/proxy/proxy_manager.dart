import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/proxy_models.dart';
import '../config/app_config.dart';
import '../tdlib/tdlib_client.dart';
import 'proxy_preferences.dart';
import 'system_proxy_config.dart';
import 'system_proxy_detector.dart';
import '../tdlib/tdlib_json.dart';

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
  static const Duration transportProxyWarmup = Duration(seconds: 3);
  static const Duration pingSettleDelay = Duration(seconds: 1);

  static const String systemProxyName = 'Системный прокси';
  static const String transportProxyName = 'Системный прокси (транспорт)';

  final List<ProxyEntry> _proxies = [];
  final List<ProxyConfig> _pendingConfigs = [];
  final List<UserProxyConfig> _pendingUserConfigs = [];
  List<UserProxyConfig> _savedUserProxies = [];
  /// TDLib `proxy` payload для pingProxy (MTProto и HTTP/SOCKS).
  final Map<int, Map<String, dynamic>> _proxyPayloadsById = {};

  StreamSubscription<Map<String, dynamic>>? _updatesSubscription;
  Timer? _healthTimer;

  ProxyStatus _status = ProxyStatus.unknown;
  bool _autoFailoverEnabled = true;
  bool _readyForFailover = false;
  bool _failoverRunning = false;
  String? _lastError;

  List<ProxyEntry> get proxies => List.unmodifiable(_proxies);
  List<UserProxyConfig> get userProxies => List.unmodifiable(_savedUserProxies);
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

  /// Snapshot на время addProxy System/Transport — не зависит от `_systemProxy`,
  /// который `setupProxies()` обнуляет при повторном входе.
  SystemProxyConfig? _pendingSystemProxy;

  /// Загрузка настроек и регистрация прокси в TDLib.
  Future<void> setupProxies() async {
    _autoFailoverEnabled = await _preferences.isAutoFailoverEnabled();
    _readyForFailover = false;
    _failoverRunning = false;
    _proxies.clear();
    _pendingConfigs.clear();
    _proxyPayloadsById.clear();
    _systemProxy = null;
    _pendingSystemProxy = null;
    _lastError = null;

    // Старый transport (127.0.0.1:12334) из binlog иначе остаётся и даёт
    // Connection refused на ping MTProto, даже когда локальный прокси выключен.
    await _purgeStoredProxies();

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
      // Локальный snapshot: ответ addProxy может прийти после повторного
      // setupProxies(), когда _systemProxy уже снова null.
      _pendingSystemProxy = systemProxy;
      _client.send({
        '@type': 'addProxy',
        'proxy': _systemProxyPayload(systemProxy),
        'enable': false,
        'comment': isTransportOnly
            ? SystemProxyConfig.transportComment
            : systemProxyName,
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
      if (hasActiveProxy) {
        _startHealthChecks();
      }
      await _registerSavedUserProxies();
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
    if (systemProxy != null && systemProxy.isConfigured && validConfigs.isNotEmpty) {
      // Дать TDLib время на DNS resolve транспортного прокси перед ping MTProto.
      await Future<void>.delayed(transportProxyWarmup);
    }
    await _enableFirstAvailable();
    if (hasActiveProxy) {
      _startHealthChecks();
    }

    await _registerSavedUserProxies();
  }

  /// Добавляет SOCKS5/HTTP прокси, заданный пользователем.
  Future<void> addUserProxy(UserProxyConfig config) async {
    _pendingUserConfigs.add(config);
    await _preferences.addUserProxy(config);
    _savedUserProxies = await _preferences.loadUserProxies();
    _client.send({
      '@type': 'addProxy',
      'proxy': _userProxyPayload(config),
      'enable': false,
      'comment': config.name,
      '@extra': 'addProxy_${config.name}',
    });
    notifyListeners();
  }

  Future<void> _registerSavedUserProxies() async {
    _savedUserProxies = await _preferences.loadUserProxies();
    for (final proxy in _savedUserProxies) {
      _pendingUserConfigs.add(proxy);
      _client.send({
        '@type': 'addProxy',
        'proxy': _userProxyPayload(proxy),
        'enable': false,
        'comment': proxy.name,
        '@extra': 'addProxy_${proxy.name}',
      });
    }
  }

  Map<String, dynamic> _userProxyPayload(UserProxyConfig proxy) {
    return {
      '@type': 'proxy',
      'server': proxy.host,
      'port': proxy.port,
      'type': proxy.type == UserProxyType.socks5
          ? {
              '@type': 'proxyTypeSocks5',
              'username': proxy.username,
              'password': proxy.password,
            }
          : {
              '@type': 'proxyTypeHttp',
              'username': proxy.username,
              'password': proxy.password,
              'http_only': proxy.httpOnly,
            },
    };
  }

  /// Удаляет все прокси из TDLib (включая transport из прошлого запуска).
  Future<void> _purgeStoredProxies() async {
    await _sendProxyOk('disableProxy', {'@type': 'disableProxy'});

    const extra = 'getProxies_purge';
    final listedFuture = _client.waitFor(
      predicate: (update) {
        if (update['@extra'] != extra) {
          return false;
        }
        final type = update['@type'];
        return type == 'proxies' ||
            type == 'addedProxies' ||
            type == 'error';
      },
      timeout: const Duration(seconds: 5),
    );
    _client.send({
      '@type': 'getProxies',
      '@extra': extra,
    });
    final listed = await listedFuture;
    if (listed == null || listed['@type'] == 'error') {
      debugPrint(
        'ProxyManager: getProxies failed: '
        '${listed?['message'] ?? 'timeout'}',
      );
      return;
    }

    final rawProxies = listed['proxies'];
    if (rawProxies is! List) {
      return;
    }

    var removed = 0;
    for (final item in rawProxies) {
      if (item is! Map) {
        continue;
      }
      final id = tdInt(item['id']);
      if (id == null || id <= 0) {
        continue;
      }
      final ok = await _sendProxyOk('removeProxy', {
        '@type': 'removeProxy',
        'proxy_id': id,
      });
      if (ok) {
        removed++;
      }
    }
    if (removed > 0) {
      debugPrint('ProxyManager: очищено старых прокси TDLib: $removed');
    }
  }

  Future<bool> _sendProxyOk(String label, Map<String, dynamic> request) async {
    final extra = '${label}_${DateTime.now().microsecondsSinceEpoch}';
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
    _client.send({...request, '@extra': extra});
    final response = await responseFuture;
    if (response == null || response['@type'] == 'error') {
      debugPrint(
        'ProxyManager: $label failed: '
        '${response?['message'] ?? 'timeout'}',
      );
      return false;
    }
    return true;
  }

  Future<void> _enableSystemProxyOnly() async {
    final systemEntry = _proxies.cast<ProxyEntry?>().firstWhere(
          (proxy) =>
              proxy != null &&
              (proxy.name == systemProxyName || proxy.name == transportProxyName),
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

  bool _isSystemLikeProxy(ProxyEntry proxy) =>
      proxy.name == systemProxyName || proxy.name == transportProxyName;

  /// Порядок failover: PhantomProxy → StealthGate → системный HTTP/SOCKS.
  List<ProxyEntry> get _failoverCandidates {
    final mtproto = <ProxyEntry>[];
    final system = <ProxyEntry>[];
    for (final proxy in _proxies) {
      if (_isSystemLikeProxy(proxy)) {
        system.add(proxy);
      } else {
        mtproto.add(proxy);
      }
    }
    return [...mtproto, ...system];
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

    final entry = _proxies[index];
    _setProxyHealth(proxyId, ProxyHealth.checking);
    _status = ProxyStatus.switching;
    notifyListeners();

    final ping = await pingProxy(proxyId);
    if (!ping.ok) {
      // Включаем всё равно: ping через Fake TLS иногда ложно падает,
      // а рабочий прокси всё равно нужен для авторизации.
      debugPrint('ProxyManager: ping ${entry.name} failed: ${ping.error}');
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

  /// Переключение на следующий рабочий прокси (ручное или auto-failover).
  ///
  /// Переключает **только** если ping следующего успешен.
  /// Иначе оставляем текущий — иначе health-check включает битый StealthGate
  /// (`Expected packet size is too big`) и рвёт сессии.
  Future<void> switchToNextProxy() async {
    final candidates = _failoverCandidates;
    if (candidates.isEmpty || _failoverRunning) {
      return;
    }

    _failoverRunning = true;
    _status = ProxyStatus.switching;
    notifyListeners();

    try {
      final currentIndex = candidates.indexWhere((proxy) => proxy.isActive);
      final startIndex = currentIndex < 0 ? 0 : currentIndex + 1;

      for (var offset = 0; offset < candidates.length; offset++) {
        final index = (startIndex + offset) % candidates.length;
        final proxy = candidates[index];
        if (proxy.isActive) {
          continue;
        }

        final ping = await pingProxy(proxy.id);
        if (ping.ok) {
          await _enableProxy(proxy.id);
          return;
        }
        _setProxyHealth(proxy.id, ProxyHealth.failed);
        debugPrint('ProxyManager: failover skip ${proxy.name}: ${ping.error}');
      }

      // Все кандидаты мертвы — не трогаем active, чтобы не усугублять обрывы.
      final active = activeProxy;
      _status = active != null ? ProxyStatus.active : ProxyStatus.error;
      _lastError =
          'Нет доступного прокси для переключения'
          '${active != null ? ' — оставлен ${active.name}' : ''}';
      notifyListeners();
    } finally {
      _failoverRunning = false;
    }
  }

  /// Вызывается при проблемах с соединением (из AuthManager).
  Future<void> handleConnectionIssue() async {
    if (!_autoFailoverEnabled || _failoverCandidates.isEmpty) {
      return;
    }
    await switchToNextProxy();
  }

  Future<({bool ok, String? error})> pingProxy(
    int proxyId, {
    int retriesOnCanceled = 2,
  }) async {
    final payload = _proxyPayloadsById[proxyId];
    final entry = _proxies.cast<ProxyEntry?>().firstWhere(
          (proxy) => proxy?.id == proxyId,
          orElse: () => null,
        );
    final name = entry?.name ?? 'прокси $proxyId';
    if (payload == null) {
      return (ok: false, error: 'Прокси $proxyId ($name) не найден в локальном кэше');
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
      'proxy': payload,
      '@extra': extra,
    });

    final response = await responseFuture;
    if (response == null) {
      _setProxyHealth(proxyId, ProxyHealth.failed);
      return (
        ok: false,
        error: 'Таймаут ping $name (${pingTimeout.inSeconds}с)',
      );
    }
    if (response['@type'] == 'error') {
      final message = response['message'] as String? ?? 'неизвестная ошибка';
      // enableProxy / реконнект часто рвут in-flight TransparentProxy → "Canceled".
      if (retriesOnCanceled > 0 && message == 'Canceled') {
        await Future<void>.delayed(pingSettleDelay);
        return pingProxy(proxyId, retriesOnCanceled: retriesOnCanceled - 1);
      }
      _setProxyHealth(proxyId, ProxyHealth.failed);
      return (ok: false, error: '$name: $message');
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
    if (state == null ||
        !_autoFailoverEnabled ||
        !_readyForFailover ||
        _failoverRunning ||
        _status == ProxyStatus.switching) {
      return;
    }

    final type = state['@type'];
    if (type == 'connectionStateWaitingForNetwork') {
      unawaited(switchToNextProxy());
    }
  }

  void _registerAddedProxy(Map<String, dynamic> addedProxy) {
    final id = tdInt(addedProxy['id']);
    if (id == null) {
      return;
    }

    final extra = addedProxy['@extra'] as String?;
    ProxyConfig? config;
    SystemProxyConfig? systemConfig;
    String? displayName;
    Map<String, dynamic>? payload;
    if (extra == 'addProxy_System') {
      displayName = systemProxyName;
      systemConfig = _pendingSystemProxy ?? _systemProxy;
      if (systemConfig != null) {
        payload = _systemProxyPayload(systemConfig);
      }
    } else if (extra == 'addProxy_Transport') {
      displayName = transportProxyName;
      systemConfig = _pendingSystemProxy ?? _systemProxy;
      if (systemConfig != null) {
        payload = _systemProxyPayload(systemConfig);
      }
    } else if (extra != null && extra.startsWith('addProxy_')) {
      final name = extra.substring('addProxy_'.length);
      final userIndex =
          _pendingUserConfigs.indexWhere((item) => item.name == name);
      if (userIndex >= 0) {
        final userConfig = _pendingUserConfigs.removeAt(userIndex);
        displayName = userConfig.name;
        payload = _userProxyPayload(userConfig);
      } else {
        final index = _pendingConfigs.indexWhere((item) => item.name == name);
        if (index >= 0) {
          config = _pendingConfigs.removeAt(index);
          displayName = config.name;
          payload = _proxyPayload(config);
        }
      }
    } else if (_pendingConfigs.isNotEmpty) {
      config = _pendingConfigs.removeAt(0);
      displayName = config.name;
      payload = _proxyPayload(config);
    }

    if (displayName == null) {
      return;
    }

    // Fallback: TDLib echo'ит server/port/type в ответе addProxy.
    payload ??= _payloadFromRegisteredProxy(addedProxy);

    if (payload != null) {
      _proxyPayloadsById[id] = payload;
    }

    final server = addedProxy['server'] as String?;
    final port = tdInt(addedProxy['port']);
    _proxies.add(
      ProxyEntry(
        id: id,
        name: displayName,
        host: config?.host ?? systemConfig?.host ?? server ?? '',
        port: config?.port ?? systemConfig?.port ?? port ?? 0,
      ),
    );
    notifyListeners();
  }

  /// Собирает ping-payload из ответа TDLib, если локальный snapshot уже сброшен.
  Map<String, dynamic>? _payloadFromRegisteredProxy(
    Map<String, dynamic> addedProxy,
  ) {
    final server = addedProxy['server'] as String?;
    final port = tdInt(addedProxy['port']);
    final type = addedProxy['type'];
    if (server == null ||
        server.isEmpty ||
        port == null ||
        port <= 0 ||
        type is! Map) {
      return null;
    }
    return {
      '@type': 'proxy',
      'server': server,
      'port': port,
      'type': Map<String, dynamic>.from(type),
    };
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
        .where((proxy) => !_isSystemLikeProxy(proxy))
        .toList(growable: false);
    if (mtprotoProxies.isEmpty) {
      await _enableSystemProxyOnly();
      return;
    }

    // Ping может ложно падать (RST/Canceled), но без enable MTProto авторизация не стартует.
    String? lastPingError;
    for (final proxy in mtprotoProxies) {
      final ping = await pingProxy(proxy.id);
      if (ping.ok) {
        await _enableProxy(proxy.id);
        return;
      }
      lastPingError = ping.error;
      debugPrint('ProxyManager: стартовый ping ${proxy.name}: ${ping.error}');
    }

    final systemEntry = _proxies.cast<ProxyEntry?>().firstWhere(
          (proxy) => proxy != null && _isSystemLikeProxy(proxy),
          orElse: () => null,
        );
    if (systemEntry != null) {
      final systemPing = await pingProxy(systemEntry.id);
      debugPrint(
        'ProxyManager: fallback ping ${systemEntry.name}: '
        '${systemPing.ok ? 'ok' : systemPing.error}',
      );
      if (systemPing.ok) {
        await _enableProxy(systemEntry.id);
        return;
      }
      lastPingError = systemPing.error;
    }

    // Все ping провалились — включаем первый MTProto (PhantomProxy), иначе TDLib
    // уходит в direct DC и «Lost connection» в РФ/DPI.
    final first = mtprotoProxies.first;
    await _enableProxy(first.id);
    _lastError =
        '${lastPingError ?? 'Ping не подтвердил доступность'}. '
        'Включён ${first.name} — проверь secret/SNI на VPS.';
    notifyListeners();
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
    _readyForFailover = true;
    _healthTimer = Timer.periodic(healthCheckInterval, (_) async {
      if (!_autoFailoverEnabled || _failoverRunning) {
        return;
      }
      final active = activeProxy;
      if (active == null) {
        return;
      }
      final ping = await pingProxy(active.id);
      if (ping.ok) {
        return;
      }
      // "Canceled" часто ложный при реконнекте.
      if (ping.error?.contains('Canceled') ?? false) {
        debugPrint(
          'ProxyManager: health ping ${active.name} canceled, skip failover',
        );
        return;
      }
      // Протокольный мусор / RST — переключение только если другой ping ok.
      if (_isHardProxyFailure(ping.error)) {
        debugPrint(
          'ProxyManager: health ${active.name} hard-fail (${ping.error}), '
          'failover only if another proxy pings ok',
        );
      }
      await switchToNextProxy();
    });
  }

  /// Явный отказ протокола/TCP — не «ложный Canceled».
  bool _isHardProxyFailure(String? error) {
    if (error == null) {
      return false;
    }
    return error.contains('Expected packet size is too big') ||
        error.contains('Connection reset by peer') ||
        error.contains('Connection refused') ||
        error.contains('Connection closed');
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _updatesSubscription?.cancel();
    super.dispose();
  }
}
