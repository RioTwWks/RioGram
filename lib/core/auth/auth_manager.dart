import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../proxy/proxy_manager.dart';
import '../tdlib/tdlib_client.dart';
import '../../models/auth_models.dart';

/// Управление авторизацией через TDLib.
class AuthManager extends ChangeNotifier {
  AuthManager({
    required TdlibClient client,
    required AppConfig config,
    ProxyManager? proxyManager,
    this.onAuthorized,
  })  : _client = client,
        _config = config,
        _proxyManager = proxyManager;

  final TdlibClient _client;
  final AppConfig _config;
  final ProxyManager? _proxyManager;
  final VoidCallback? onAuthorized;

  AuthPhase _phase = AuthPhase.initializing;
  String? _errorMessage;
  String? _phoneNumber;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  AuthPhase get phase => _phase;
  String? get errorMessage => _errorMessage;
  String? get phoneNumber => _phoneNumber;

  TdlibClient get client => _client;

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

  void logOut() {
    _client.send({'@type': 'logOut'});
  }

  void _handleUpdate(Map<String, dynamic> update) {
    final type = update['@type'];

    switch (type) {
      case 'updateAuthorizationState':
        _handleAuthorizationState(
          update['authorization_state'] as Map<String, dynamic>,
        );
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
        onAuthorized?.call();
      case 'authorizationStateClosing':
      case 'authorizationStateClosed':
        _phase = AuthPhase.waitPhoneNumber;
        _errorMessage = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
