import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_state_predicates.dart';
import '../config/app_config.dart';
import 'tdlib_client_interface.dart';
import 'web/tdlib_js_bridge.dart';

export 'tdlib_client_interface.dart';

/// TDLib JSON API через tdweb (WebAssembly) + WSS-транспорт.
class TdlibClient {
  TdlibClient();

  bool _isRunning = false;
  bool _clientCreated = false;
  Map<String, dynamic>? _initialAuthorizationUpdate;
  String? _initialAuthorizationState;

  final StreamController<Map<String, dynamic>> _updatesController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get updates => _updatesController.stream;

  bool get isAvailable => _clientCreated;

  String? get initialAuthorizationState => _initialAuthorizationState;

  Map<String, dynamic>? takeInitialAuthorizationUpdate() {
    final update = _initialAuthorizationUpdate;
    _initialAuthorizationUpdate = null;
    return update;
  }

  Future<void> ensureClient() async {
    if (_clientCreated) {
      return;
    }

    if (!TdlibJsBridge.isSupported) {
      throw TdlibException(
        'WSS-транспорт не инициализирован. Подключите web/js/wss_proxy_hook.js '
        'в index.html до flutter_bootstrap.js.',
      );
    }

    if (!TdlibJsBridge.isTdwebLoaded) {
      throw TdlibException(
        'tdweb не загружен. Соберите tdweb (td/example/web) и подключите dist/tdweb.js. '
        'См. docs/WEB_TRANSPORT.md.',
      );
    }

    _isRunning = true;
    try {
      _initialAuthorizationUpdate = await TdlibJsBridge.createTdlibClient(
        onUpdate: _handleUpdate,
        instanceName: 'riogram',
        authWaitTimeout: kIsWeb
            ? const Duration(seconds: 120)
            : const Duration(seconds: 45),
      );
      _initialAuthorizationState = authorizationStateType(
        _initialAuthorizationUpdate ?? const {},
      );
      _clientCreated = true;
    } catch (error) {
      _isRunning = false;
      rethrow;
    }
  }

  void setNetworkEnabled(bool enabled) {
    send({
      '@type': 'setNetworkType',
      'type': {
        '@type': enabled ? 'networkTypeOther' : 'networkTypeNone',
      },
    });
  }

  Future<void> configure(
    AppConfig config, {
    String? accountDirectorySuffix,
  }) async {
    if (!_clientCreated) {
      throw TdlibException('TDLib клиент не создан');
    }
    if (!config.hasApiCredentials) {
      throw TdlibException(
        'Укажите TELEGRAM_API_ID и TELEGRAM_API_HASH в файле .env',
      );
    }

    send({
      '@type': 'setLogVerbosityLevel',
      'new_verbosity_level': kDebugMode ? 2 : 0,
    });

    final directories = await _resolveDirectories(
      accountSuffix: accountDirectorySuffix,
    );
    send({
      '@type': 'setTdlibParameters',
      'use_test_dc': false,
      'database_directory': directories.database,
      'files_directory': directories.files,
      'use_file_database': true,
      'use_chat_info_database': true,
      'use_message_database': true,
      'use_secret_chats': true,
      'api_id': config.apiId,
      'api_hash': config.apiHash,
      'system_language_code': 'ru',
      'device_model': 'RioGram Web',
      'system_version': 'Browser',
      'application_version': '1.0.0',
    });
  }

  Future<void> init(
    AppConfig config, {
    String? accountDirectorySuffix,
  }) async {
    await ensureClient();
    await configure(
      config,
      accountDirectorySuffix: accountDirectorySuffix,
    );
  }

  void send(Map<String, dynamic> request) {
    if (!_clientCreated) {
      throw TdlibException('TDLib не инициализирован');
    }
    TdlibJsBridge.sendTdlibQuery(request);
  }

  Future<Map<String, dynamic>?> waitFor({
    required bool Function(Map<String, dynamic> update) predicate,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = Completer<Map<String, dynamic>?>();
    late final StreamSubscription<Map<String, dynamic>> subscription;
    Timer? timer;

    subscription = updates.listen((update) {
      if (predicate(update) && !completer.isCompleted) {
        timer?.cancel();
        completer.complete(update);
      }
    });

    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }

  Future<void> dispose() async {
    _isRunning = false;
    if (_clientCreated) {
      send({'@type': 'close'});
      await Future<void>.delayed(const Duration(milliseconds: 200));
      TdlibJsBridge.closeTdlibClient();
    }
    _clientCreated = false;
    await _updatesController.close();
  }

  /// Закрывает tdweb-клиент без уничтожения потока updates (пересоздание после сброса IndexedDB).
  Future<void> resetForStorageClear() async {
    _isRunning = false;
    if (_clientCreated) {
      TdlibJsBridge.closeTdlibClient();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    _clientCreated = false;
    _initialAuthorizationUpdate = null;
    _initialAuthorizationState = null;
  }

  void _handleUpdate(Map<String, dynamic> update) {
    if (!_isRunning) {
      return;
    }
    _updatesController.add(update);
  }

  Future<({String database, String files})> _resolveDirectories({
    String? accountSuffix,
  }) async {
    // tdweb хранит данные в IndexedDB; path_provider на Web не поддерживает
    // getApplicationSupportDirectory — используем виртуальные пути.
    final suffix = accountSuffix != null && accountSuffix.isNotEmpty
        ? '/account_$accountSuffix'
        : '';
    return (
      database: 'tdlib_db$suffix',
      files: 'tdlib_files$suffix',
    );
  }
}
