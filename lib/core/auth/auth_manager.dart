import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/auth_models.dart';
import '../config/app_config.dart';
import '../proxy/proxy_manager.dart';
import '../tdlib/tdlib_client.dart';

/// Управление авторизацией через TDLib.
class AuthManager extends ChangeNotifier {
  AuthManager({
    required TdlibClient client,
    required AppConfig config,
    ProxyManager? proxyManager,
  })  : _client = client,
        _config = config,
        _proxyManager = proxyManager;

  final TdlibClient _client;
  final AppConfig _config;
  final ProxyManager? _proxyManager;

  AuthPhase _phase = AuthPhase.initializing;
  String? _errorMessage;
  String? _phoneNumber;
  final List<ChatSummary> _chats = [];
  StreamSubscription<Map<String, dynamic>>? _subscription;

  AuthPhase get phase => _phase;
  String? get errorMessage => _errorMessage;
  String? get phoneNumber => _phoneNumber;
  List<ChatSummary> get chats => List.unmodifiable(_chats);

  Future<void> initialize() async {
    _phase = AuthPhase.initializing;
    _errorMessage = null;
    notifyListeners();

    try {
      await _client.init(_config);
      _subscription = _client.updates.listen(_handleUpdate);
      await _proxyManager?.setupProxies();
      _client.send({'@type': 'getAuthorizationState'});
    } catch (error) {
      _phase = AuthPhase.error;
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  void submitPhoneNumber(String phoneNumber) {
    _phoneNumber = phoneNumber.trim();
    _client.send({
      '@type': 'setAuthenticationPhoneNumber',
      'phone_number': _phoneNumber,
    });
  }

  void submitCode(String code) {
    _client.send({
      '@type': 'checkAuthenticationCode',
      'code': code.trim(),
    });
  }

  void submitPassword(String password) {
    _client.send({
      '@type': 'checkAuthenticationPassword',
      'password': password,
    });
  }

  void loadChats() {
    _client.send({
      '@type': 'getChats',
      'chat_list': {'@type': 'chatListMain'},
      'limit': 50,
    });
  }

  void _handleUpdate(Map<String, dynamic> update) {
    final type = update['@type'];

    switch (type) {
      case 'updateAuthorizationState':
        _handleAuthorizationState(update['authorization_state'] as Map<String, dynamic>);
      case 'updateNewChat':
        _handleNewChat(update['chat'] as Map<String, dynamic>);
      case 'chats':
        _handleChats(update);
      case 'error':
        _phase = AuthPhase.error;
        _errorMessage = update['message'] as String? ?? 'Неизвестная ошибка TDLib';
        notifyListeners();
    }
  }

  void _handleAuthorizationState(Map<String, dynamic> state) {
    switch (state['@type']) {
      case 'authorizationStateWaitPhoneNumber':
        _phase = AuthPhase.waitPhoneNumber;
      case 'authorizationStateWaitCode':
        _phase = AuthPhase.waitCode;
      case 'authorizationStateWaitPassword':
        _phase = AuthPhase.waitPassword;
      case 'authorizationStateReady':
        _phase = AuthPhase.ready;
        loadChats();
      case 'authorizationStateClosing':
      case 'authorizationStateClosed':
        _phase = AuthPhase.error;
        _errorMessage = 'Соединение с Telegram закрыто';
    }
    notifyListeners();
  }

  void _handleChats(Map<String, dynamic> update) {
    final chatIds = (update['chat_ids'] as List<dynamic>? ?? []).cast<int>();
    for (final chatId in chatIds) {
      _client.send({
        '@type': 'getChat',
        'chat_id': chatId,
      });
    }
  }

  void _handleNewChat(Map<String, dynamic> chat) {
    final id = chat['id'] as int?;
    final title = chat['title'] as String?;
    if (id == null || title == null) {
      return;
    }

    final existingIndex = _chats.indexWhere((item) => item.id == id);
    final summary = ChatSummary(id: id, title: title);
    if (existingIndex >= 0) {
      _chats[existingIndex] = summary;
    } else {
      _chats.add(summary);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
