import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import 'tdlib_bindings.dart';

typedef TdlibUpdateCallback = void Function(Map<String, dynamic> update);

/// Обёртка над TDLib JSON API через FFI.
class TdlibClient {
  TdlibClient();

  TdlibBindings? _bindings;
  Pointer<Void>? _client;
  Timer? _receiveTimer;
  bool _isRunning = false;

  final StreamController<Map<String, dynamic>> _updatesController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get updates => _updatesController.stream;

  bool get isAvailable => _bindings != null && _client != null;

  /// Создаёт FFI-клиент и запускает цикл приёма обновлений.
  Future<void> ensureClient() async {
    if (_client != null) {
      return;
    }

    _bindings = TdlibBindings.load();
    if (_bindings == null) {
      throw TdlibException(
        'libtdjson не найден. Соберите TDLib (@build-tdlib), скопируйте библиотеку '
        'в каталог runner и (на Windows) положите рядом с exe зависимости vcpkg: '
        'libssl-3-x64.dll, libcrypto-3-x64.dll, zlib1.dll.',
      );
    }

    _bindings!.bind();
    _client = _bindings!.createClient();
    _isRunning = true;
    _startReceiveLoop();
  }

  /// Включает или отключает сетевую активность TDLib (до настройки прокси — off).
  void setNetworkEnabled(bool enabled) {
    send({
      '@type': 'setNetworkType',
      'type': {
        '@type': enabled ? 'networkTypeOther' : 'networkTypeNone',
      },
    });
  }

  /// Отправляет параметры TDLib. Вызывать после подписки на [updates].
  Future<void> configure(
    AppConfig config, {
    String? accountDirectorySuffix,
  }) async {
    if (_client == null) {
      throw TdlibException('TDLib клиент не создан');
    }
    if (!config.hasApiCredentials) {
      throw TdlibException(
        'Укажите TELEGRAM_API_ID и TELEGRAM_API_HASH в файле .env',
      );
    }

    // 2 = warnings+ в debug (`flutter run`); 0 = только fatal в release.
    send({
      '@type': 'setLogVerbosityLevel',
      'new_verbosity_level': kDebugMode ? 2 : 0,
    });
    if (kDebugMode) {
      debugPrint('[Tdlib] log verbosity set to 2 (debug build)');
    }

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
      'device_model': 'RioGram',
      'system_version': Platform.operatingSystemVersion,
      'application_version': '1.0.0',
    });
  }

  /// Создаёт клиент и отправляет параметры (удобно для простых сценариев).
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

  /// Отправка команды в TDLib.
  void send(Map<String, dynamic> request) {
    final client = _client;
    final bindings = _bindings;
    if (client == null || bindings == null) {
      throw TdlibException('TDLib не инициализирован');
    }
    bindings.send(client, jsonEncode(request));
  }

  /// Ожидание обновления, удовлетворяющего условию.
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
    _receiveTimer?.cancel();
    final client = _client;
    final bindings = _bindings;
    if (client != null && bindings != null) {
      bindings.send(client, jsonEncode({'@type': 'close'}));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      bindings.destroy(client);
    }
    _client = null;
    _bindings = null;
    await _updatesController.close();
  }

  void _startReceiveLoop() {
    _receiveTimer?.cancel();
    _receiveTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _pollUpdates();
    });
  }

  void _pollUpdates() {
    if (!_isRunning) {
      return;
    }
    final client = _client;
    final bindings = _bindings;
    if (client == null || bindings == null) {
      return;
    }

    while (true) {
      final raw = bindings.receive(client, timeout: 0.0);
      if (raw == null || raw.isEmpty) {
        break;
      }
      try {
        final update = jsonDecode(raw) as Map<String, dynamic>;
        _updatesController.add(update);
      } catch (error) {
        debugPrint('TDLib: ошибка парсинга обновления: $error');
      }
    }
  }

  Future<({String database, String files})> _resolveDirectories({
    String? accountSuffix,
  }) async {
    final appDir = await getApplicationSupportDirectory();
    final suffix = accountSuffix != null && accountSuffix.isNotEmpty
        ? '/account_$accountSuffix'
        : '';
    final database = '${appDir.path}/tdlib_db$suffix';
    final files = '${appDir.path}/tdlib_files$suffix';
    await Directory(database).create(recursive: true);
    await Directory(files).create(recursive: true);
    return (database: database, files: files);
  }
}

class TdlibException implements Exception {
  TdlibException(this.message);

  final String message;

  @override
  String toString() => 'TdlibException: $message';
}
