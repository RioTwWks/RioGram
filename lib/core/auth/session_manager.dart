import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/session_models.dart';
import '../tdlib/tdlib_client.dart';

/// Активные сессии Telegram и их завершение.
class SessionManager extends ChangeNotifier {
  SessionManager({required TdlibClient client}) : _client = client;

  final TdlibClient _client;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  SessionsListModel? _sessions;
  var _isLoading = false;
  var _isTerminating = false;
  String? _lastError;

  SessionsListModel? get sessions => _sessions;
  bool get isLoading => _isLoading;
  bool get isTerminating => _isTerminating;
  String? get lastError => _lastError;

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void loadActiveSessions() {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    _client.send({
      '@type': 'getActiveSessions',
      '@extra': 'sessions_list',
    });
  }

  void terminateSession(int sessionId) {
    _isTerminating = true;
    _lastError = null;
    notifyListeners();
    _client.send({
      '@type': 'terminateSession',
      'session_id': sessionId,
      '@extra': 'sessions_terminate_$sessionId',
    });
  }

  void terminateAllOtherSessions() {
    _isTerminating = true;
    _lastError = null;
    notifyListeners();
    _client.send({
      '@type': 'terminateAllOtherSessions',
      '@extra': 'sessions_terminate_all',
    });
  }

  void _handleUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case 'sessions':
        _handleSessions(update);
      case 'ok':
        _handleOk(update);
      case 'error':
        _handleError(update);
    }
  }

  void _handleSessions(Map<String, dynamic> update) {
    if (update['@extra'] != 'sessions_list') {
      return;
    }
    _sessions = SessionsListModel.fromTdlib(update);
    _isLoading = false;
    notifyListeners();
  }

  void _handleOk(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('sessions_')) {
      return;
    }
    _isTerminating = false;
    loadActiveSessions();
  }

  void _handleError(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('sessions_')) {
      return;
    }
    _isLoading = false;
    _isTerminating = false;
    _lastError = update['message'] as String? ?? 'Ошибка сессий';
    notifyListeners();
  }
}
