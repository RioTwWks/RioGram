import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/wss_proxy_models.dart';
import '../tdlib/tdlib_client.dart';
import '../tdlib/web/tdlib_js_bridge.dart';
import '../tdlib/web/wss_url_rewriter.dart';
import 'web_socket_proxy_preferences.dart';

enum WebProxyStatus { unknown, active, reconnecting, error, disabled }

/// Управление WSS-прокси для Web-платформы (§8.2).
class WebProxyManager extends ChangeNotifier {
  WebProxyManager({
    required TdlibClient client,
    WebSocketProxyPreferences? preferences,
  })  : _client = client,
        _preferences = preferences ?? WebSocketProxyPreferences();

  final TdlibClient _client;
  final WebSocketProxyPreferences _preferences;

  static const Duration healthCheckInterval = Duration(seconds: 10);
  static const Duration reconnectCooldown = Duration(seconds: 2);

  WssProxyConfig _config = const WssProxyConfig();
  WebProxyStatus _status = WebProxyStatus.unknown;
  WssTransportStatus _transportStatus = const WssTransportStatus(
    state: WssTransportState.idle,
  );
  String? _lastError;
  Timer? _healthTimer;
  Timer? _reconnectTimer;
  var _reconnectAttempt = 0;
  var _isApplying = false;

  WssProxyConfig get config => _config;
  WebProxyStatus get status => _status;
  WssTransportStatus get transportStatus => _transportStatus;
  String? get lastError => _lastError;

  bool get isProxyEnabled => _config.enabled && _config.isConfigured;

  String? get activeProxyUrl =>
      isProxyEnabled ? WssUrlRewriter.normalizeProxyBase(_config.url) : null;

  /// Загружает настройки, применяет WSS hook и запускает мониторинг.
  Future<void> setup() async {
    _config = await _preferences.load();
    await applyConfig(_config, persist: false);
    _startHealthMonitor();
  }

  Future<void> applyConfig(
    WssProxyConfig config, {
    bool persist = true,
  }) async {
    if (_isApplying) {
      return;
    }
    _isApplying = true;
    try {
      _config = config;
      if (persist) {
        await _preferences.save(config);
      }

      TdlibJsBridge.applyWssConfig(config);
      TdlibJsBridge.setTransportStateCallback(_onTransportState);

      if (!config.enabled || !config.isConfigured) {
        _status = WebProxyStatus.disabled;
        _lastError = null;
      } else if (_transportStatus.state == WssTransportState.connected) {
        _status = WebProxyStatus.active;
      } else {
        _status = WebProxyStatus.unknown;
      }
      notifyListeners();
    } finally {
      _isApplying = false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    await applyConfig(_config.copyWith(enabled: enabled));
  }

  Future<void> setProxyUrl(String url) async {
    await applyConfig(_config.copyWith(url: url.trim()));
  }

  Future<void> setAutoReconnect(bool enabled) async {
    await applyConfig(_config.copyWith(autoReconnect: enabled));
  }

  /// Тест переписывания URL (без реального подключения).
  String previewRewrite(String telegramUrl) {
    return TdlibJsBridge.rewriteUrl(telegramUrl, _config);
  }

  void _onTransportState(WssTransportStatus status) {
    _transportStatus = status;
    if (status.state == WssTransportState.connected) {
      _status = WebProxyStatus.active;
      _reconnectAttempt = 0;
      _lastError = null;
    } else if (status.state == WssTransportState.reconnecting) {
      _status = WebProxyStatus.reconnecting;
    } else if (status.state == WssTransportState.failed && isProxyEnabled) {
      _status = WebProxyStatus.error;
      _lastError = status.lastError;
      _scheduleReconnect();
    }
    notifyListeners();
  }

  void _startHealthMonitor() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(healthCheckInterval, (_) {
      _transportStatus = TdlibJsBridge.readTransportStatus();
      if (_transportStatus.state == WssTransportState.failed &&
          _config.autoReconnect &&
          isProxyEnabled) {
        _scheduleReconnect();
      }
      notifyListeners();
    });
  }

  void _scheduleReconnect() {
    if (!_config.autoReconnect || !isProxyEnabled) {
      return;
    }
    if (_reconnectTimer?.isActive ?? false) {
      return;
    }
    if (_reconnectAttempt >= _config.maxReconnectAttempts) {
      _status = WebProxyStatus.error;
      _lastError = 'Исчерпаны попытки переподключения WSS';
      notifyListeners();
      return;
    }

    _reconnectAttempt += 1;
    _status = WebProxyStatus.reconnecting;
    notifyListeners();

    final delay = reconnectCooldown * _reconnectAttempt;
    _reconnectTimer = Timer(delay, () {
      if (!isProxyEnabled) {
        return;
      }
      debugPrint(
        'WebProxyManager: переподключение WSS (попытка $_reconnectAttempt)',
      );
      _client.setNetworkEnabled(false);
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        _client.setNetworkEnabled(true);
      });
    });
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }
}
