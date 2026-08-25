import 'package:flutter/foundation.dart';

import '../../../models/wss_proxy_models.dart';
import 'tdlib_js_bridge_impl.dart'
    if (dart.library.js_util) 'tdlib_js_bridge_impl_web.dart';
import 'wss_url_rewriter.dart';

/// JS-мост к `window.RioGramWssProxy` и `window.RioGramTdlib` (только Web).
abstract final class TdlibJsBridge {
  static bool get isSupported => kIsWeb && JsBridgeImpl.hasGlobal('RioGramWssProxy');

  static bool get isTdwebLoaded =>
      kIsWeb &&
      JsBridgeImpl.hasGlobal('RioGramTdlib') &&
      JsBridgeImpl.callBool('RioGramTdlib', 'isAvailable');

  static void applyWssConfig(WssProxyConfig config) {
    if (!isSupported) {
      return;
    }
    JsBridgeImpl.callVoid('RioGramWssProxy', 'writeConfig', [config.toJson()]);
  }

  static WssProxyConfig readWssConfig() {
    if (!isSupported) {
      return const WssProxyConfig();
    }
    final raw = JsBridgeImpl.callDynamic('RioGramWssProxy', 'readConfig');
    if (raw is Map) {
      return WssProxyConfig.fromJson(Map<String, dynamic>.from(raw));
    }
    return const WssProxyConfig();
  }

  static String rewriteUrl(String originalUrl, WssProxyConfig config) {
    if (isSupported) {
      final fromJs = JsBridgeImpl.callString(
        'RioGramWssProxy',
        'rewriteUrl',
        [originalUrl],
      );
      if (fromJs != null) {
        return fromJs;
      }
    }
    return WssUrlRewriter.rewrite(originalUrl: originalUrl, config: config);
  }

  static WssTransportStatus readTransportStatus() {
    if (!isSupported) {
      return const WssTransportStatus(state: WssTransportState.idle);
    }
    final raw = JsBridgeImpl.callDynamic('RioGramWssProxy', 'getTransportStatus');
    if (raw is! Map) {
      return const WssTransportStatus(state: WssTransportState.idle);
    }
    return _parseStatus(raw);
  }

  static void setTransportStateCallback(void Function(WssTransportStatus) callback) {
    if (!JsBridgeImpl.hasGlobal('RioGramTdlib')) {
      return;
    }
    JsBridgeImpl.setCallback('RioGramTdlib', 'setTransportStateCallback', (raw) {
      if (raw is Map) {
        callback(_parseStatus(raw));
      }
    });
  }

  static Future<void> createTdlibClient({
    required void Function(Map<String, dynamic> update) onUpdate,
    String instanceName = 'riogram',
  }) async {
    if (!JsBridgeImpl.hasGlobal('RioGramTdlib')) {
      throw StateError('RioGramTdlib bridge не загружен');
    }

    final created = JsBridgeImpl.callBool('RioGramTdlib', 'create', [
      {
        'instanceName': instanceName,
        'jsLogVerbosityLevel': kDebugMode ? 'info' : 'warning',
        'logVerbosityLevel': kDebugMode ? 2 : 0,
        'useDatabase': true,
        'onUpdate': (dynamic update) {
          if (update is Map) {
            onUpdate(Map<String, dynamic>.from(update));
          }
        },
      },
    ]);
    if (!created) {
      throw StateError('Не удалось создать tdweb-клиент');
    }
  }

  static void sendTdlibQuery(Map<String, dynamic> request) {
    JsBridgeImpl.callVoid('RioGramTdlib', 'send', [request]);
  }

  static void closeTdlibClient() {
    if (JsBridgeImpl.hasGlobal('RioGramTdlib')) {
      JsBridgeImpl.callVoid('RioGramTdlib', 'close');
    }
  }

  static WssTransportStatus _parseStatus(Map<dynamic, dynamic> raw) {
    return WssTransportStatus(
      state: _parseState(raw['state'] as String?),
      activeUrl: raw['activeUrl'] as String?,
      lastError: raw['lastError'] as String?,
      reconnectAttempt: raw['reconnectAttempt'] as int? ?? 0,
    );
  }

  static WssTransportState _parseState(String? value) {
    return switch (value) {
      'connecting' => WssTransportState.connecting,
      'connected' => WssTransportState.connected,
      'reconnecting' => WssTransportState.reconnecting,
      'failed' => WssTransportState.failed,
      _ => WssTransportState.idle,
    };
  }
}
