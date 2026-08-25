import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/secret_chat_models.dart';
import '../tdlib/tdlib_client.dart';
import 'tdlib_secret_parser.dart';

/// Секретные чаты: создание, E2E-состояние, TTL.
class SecretChatManager extends ChangeNotifier {
  SecretChatManager({required TdlibClient client}) : _client = client;

  final TdlibClient _client;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  final Map<int, SecretChatSummary> _secretChatsById = {};
  final Map<int, SecretChatTtlPreset> _ttlByChatId = {};
  var _isCreating = false;
  String? _lastError;

  Map<int, SecretChatSummary> get secretChatsById =>
      Map.unmodifiable(_secretChatsById);
  bool get isCreating => _isCreating;
  String? get lastError => _lastError;

  SecretChatSummary? secretChatForId(int secretChatId) =>
      _secretChatsById[secretChatId];

  SecretChatTtlPreset ttlForChat(int chatId) =>
      _ttlByChatId[chatId] ?? SecretChatTtlPreset.off;

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void createSecretChat(int userId) {
    _isCreating = true;
    _lastError = null;
    notifyListeners();
    _client.send({
      '@type': 'createNewSecretChat',
      'user_id': userId,
      '@extra': 'secret_create_$userId',
    });
  }

  void loadSecretChat(int secretChatId) {
    _client.send({
      '@type': 'getSecretChat',
      'secret_chat_id': secretChatId,
      '@extra': 'secret_get_$secretChatId',
    });
  }

  void closeSecretChat(int secretChatId) {
    _client.send({
      '@type': 'closeSecretChat',
      'secret_chat_id': secretChatId,
      '@extra': 'secret_close_$secretChatId',
    });
  }

  void setChatTtl(int chatId, SecretChatTtlPreset preset) {
    _ttlByChatId[chatId] = preset;
    _client.send({
      '@type': 'setChatMessageAutoDeleteTime',
      'chat_id': chatId,
      'message_auto_delete_time': preset.seconds,
      '@extra': 'secret_ttl_$chatId',
    });
    notifyListeners();
  }

  Map<String, dynamic>? selfDestructTypeForChat(int chatId) {
    return ttlForChat(chatId).toSelfDestructType();
  }

  void _handleUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case 'secretChat':
        _handleSecretChatResponse(update);
      case 'chat':
        _handleCreatedChat(update);
      case 'updateSecretChat':
        _handleSecretChatUpdate(update);
      case 'ok':
        _handleOk(update);
      case 'error':
        _handleError(update);
    }
  }

  void _handleSecretChatResponse(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null ||
        (!extra.startsWith('secret_get_') &&
            !extra.startsWith('secret_create_'))) {
      return;
    }
    _applySecretChat(update);
  }

  void _handleSecretChatUpdate(Map<String, dynamic> update) {
    final raw = update['secret_chat'] as Map<String, dynamic>?;
    if (raw == null) {
      return;
    }
    _applySecretChat(raw);
  }

  void _applySecretChat(Map<String, dynamic> json) {
    final summary = TdlibSecretParser.parseSecretChat(json);
    _secretChatsById[summary.id] = summary;
    _isCreating = false;
    notifyListeners();
  }

  void _handleCreatedChat(Map<String, dynamic> update) {
    if (update['@extra'] == null ||
        !(update['@extra'] as String).startsWith('secret_create_')) {
      return;
    }
    _isCreating = false;
    notifyListeners();
  }

  void _handleOk(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('secret_')) {
      return;
    }
    if (extra.startsWith('secret_close_')) {
      final id = int.tryParse(extra.substring('secret_close_'.length));
      if (id != null) {
        final current = _secretChatsById[id];
        if (current != null) {
          _secretChatsById[id] = current.copyWith(
            state: SecretChatStateKind.closed,
          );
        }
      }
    }
    notifyListeners();
  }

  void _handleError(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('secret_')) {
      return;
    }
    _isCreating = false;
    _lastError = update['message'] as String? ?? 'Ошибка секретного чата';
    notifyListeners();
  }
}
