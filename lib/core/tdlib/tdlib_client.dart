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

  bool get isAvailable => _bindings != null;

  /// Инициализация TDLib: загрузка libtdjson и установка параметров.
  Future<void> init(AppConfig config) async {
    if (!config.hasApiCredentials) {
      throw TdlibException(
        'Укажите TELEGRAM_API_ID и TELEGRAM_API_HASH в файле .env',
      );
    }

    _bindings = TdlibBindings.load();
    if (_bindings == null) {
      throw TdlibException(
        'libtdjson не найден. Соберите TDLib (@build-tdlib) и скопируйте библиотеку '
        'в каталог runner для вашей платформы.',
      );
    }

    _bindings!.bind();
    _client = _bindings!.createClient();
    _isRunning = true;
    _startReceiveLoop();

    _bindings!.send(_client!, jsonEncode({
      '@type': 'setLogVerbosityLevel',
      'new_verbosity_level': kDebugMode ? 1 : 0,
    }));

    final directories = await _resolveDirectories();
    send({
      '@type': 'setTdlibParameters',
      'use_test_dc': false,
      'database_directory': directories.database,
      'files_directory': directories.files,
      'use_file_database': true,
      'use_chat_info_database': true,
      'use_message_database': true,
      'use_secret_chats': false,
      'api_id': config.apiId,
      'api_hash': config.apiHash,
      'system_language_code': 'ru',
      'device_model': 'RioGram',
      'system_version': Platform.operatingSystemVersion,
      'application_version': '0.1.0',
    });
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

  Future<({String database, String files})> _resolveDirectories() async {
    final appDir = await getApplicationSupportDirectory();
    final database = '${appDir.path}/tdlib_db';
    final files = '${appDir.path}/tdlib_files';
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
