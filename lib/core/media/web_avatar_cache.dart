import 'dart:async';

import 'package:flutter/foundation.dart';

import '../tdlib/tdlib_client.dart';
import '../tdlib/web/tdlib_js_bridge.dart';

/// Кэш blob-URL аватаров для Web (tdweb хранит файлы в IndexedDB, не на диске).
class WebAvatarCache extends ChangeNotifier {
  WebAvatarCache({required TdlibClient client}) : _client = client;

  final TdlibClient _client;
  final Map<int, String> _urls = {};
  final Set<int> _loading = {};
  StreamSubscription<Map<String, dynamic>>? _subscription;

  String? urlFor(int? fileId) {
    if (fileId == null) {
      return null;
    }
    return _urls[fileId];
  }

  void start() {
    if (!kIsWeb) {
      return;
    }
    _subscription ??= _client.updates.listen(_handleUpdate);
  }

  void request(int fileId) {
    if (!kIsWeb || _urls.containsKey(fileId) || _loading.contains(fileId)) {
      return;
    }
    unawaited(_load(fileId));
  }

  void _handleUpdate(Map<String, dynamic> update) {
    if (update['@type'] != 'updateFile') {
      return;
    }
    final file = update['file'] as Map<String, dynamic>?;
    if (file == null) {
      return;
    }
    final fileId = _readFileId(file['id']);
    if (fileId == null) {
      return;
    }
    final local = file['local'] as Map<String, dynamic>?;
    final completed = local?['is_downloading_completed'] as bool? ?? false;
    if (completed) {
      request(fileId);
    }
  }

  Future<void> _load(int fileId) async {
    _loading.add(fileId);
    try {
      final url = await TdlibJsBridge.readFileBlobUrl(fileId);
      if (url != null && url.isNotEmpty) {
        _urls[fileId] = url;
        notifyListeners();
      }
    } finally {
      _loading.remove(fileId);
    }
  }

  int? _readFileId(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
