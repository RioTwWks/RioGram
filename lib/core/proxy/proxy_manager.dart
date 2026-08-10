import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../tdlib/tdlib_client.dart';

enum ProxyStatus { unknown, active, switching, error }

/// Управление прокси PhantomProxy / StealthGate с автоматическим failover.
class ProxyManager extends ChangeNotifier {
  ProxyManager({
    required TdlibClient client,
    required AppConfig config,
  })  : _client = client,
        _config = config;

  final TdlibClient _client;
  final AppConfig _config;

  final List<int> _proxyIds = [];
  int? _activeProxyId;
  ProxyStatus _status = ProxyStatus.unknown;
  String? _activeProxyName;
  Timer? _healthTimer;

  ProxyStatus get status => _status;
  String? get activeProxyName => _activeProxyName;

  /// Регистрация прокси в TDLib (PhantomProxy первым, StealthGate вторым).
  Future<void> setupProxies() async {
    _proxyIds.clear();
    _activeProxyId = null;
    _status = ProxyStatus.unknown;

    final proxies = [
      _config.phantomProxy,
      _config.stealthProxy,
    ].whereType<ProxyConfig>().where((proxy) => proxy.isConfigured);

    for (final proxy in proxies) {
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

    _client.updates.listen(_handleProxyUpdate);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _enableFirstAvailable();
    _startHealthChecks();
  }

  void _handleProxyUpdate(Map<String, dynamic> update) {
    if (update['@type'] == 'updateProxy') {
      _activeProxyId = update['proxy_id'] as int?;
      notifyListeners();
      return;
    }

    if (update['@type'] == 'proxy') {
      final id = update['id'] as int?;
      if (id != null && !_proxyIds.contains(id)) {
        _proxyIds.add(id);
      }
    }
  }

  Future<void> _enableFirstAvailable() async {
    if (_proxyIds.isEmpty) {
      _status = ProxyStatus.unknown;
      _activeProxyName = null;
      notifyListeners();
      return;
    }

    for (var index = 0; index < _proxyIds.length; index++) {
      final proxyId = _proxyIds[index];
      final isHealthy = await _pingProxy(proxyId);
      if (isHealthy) {
        _client.send({'@type': 'enableProxy', 'proxy_id': proxyId});
        _activeProxyId = proxyId;
        _activeProxyName = _proxyNameForIndex(index);
        _status = ProxyStatus.active;
        notifyListeners();
        return;
      }
    }

    _status = ProxyStatus.error;
    notifyListeners();
  }

  Future<void> switchToNextProxy() async {
    if (_proxyIds.isEmpty) {
      return;
    }

    _status = ProxyStatus.switching;
    notifyListeners();

    final currentIndex = _proxyIds.indexOf(_activeProxyId ?? -1);
    final startIndex = currentIndex < 0 ? 0 : currentIndex + 1;

    for (var offset = 0; offset < _proxyIds.length; offset++) {
      final index = (startIndex + offset) % _proxyIds.length;
      final proxyId = _proxyIds[index];
      if (proxyId == _activeProxyId) {
        continue;
      }

      final isHealthy = await _pingProxy(proxyId);
      if (isHealthy) {
        _client.send({'@type': 'enableProxy', 'proxy_id': proxyId});
        _activeProxyId = proxyId;
        _activeProxyName = _proxyNameForIndex(index);
        _status = ProxyStatus.active;
        notifyListeners();
        return;
      }
    }

    _status = ProxyStatus.error;
    notifyListeners();
  }

  Future<bool> _pingProxy(int proxyId) async {
    final completer = Completer<bool>();
    late final StreamSubscription<Map<String, dynamic>> subscription;

    subscription = _client.updates.listen((update) {
      if (update['@type'] == 'ok' && !completer.isCompleted) {
        completer.complete(true);
      }
      if (update['@type'] == 'error' && !completer.isCompleted) {
        completer.complete(false);
      }
    });

    _client.send({
      '@type': 'pingProxy',
      'proxy_id': proxyId,
    });

    final result = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => false,
    );
    await subscription.cancel();
    return result;
  }

  String _proxyNameForIndex(int index) {
    if (index == 0 && _config.phantomProxy != null) {
      return _config.phantomProxy!.name;
    }
    if (_config.stealthProxy != null) {
      return _config.stealthProxy!.name;
    }
    return 'Proxy $index';
  }

  void _startHealthChecks() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final activeId = _activeProxyId;
      if (activeId == null) {
        return;
      }
      final isHealthy = await _pingProxy(activeId);
      if (!isHealthy) {
        await switchToNextProxy();
      }
    });
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    super.dispose();
  }
}
