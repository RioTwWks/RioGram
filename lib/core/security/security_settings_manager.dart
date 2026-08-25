import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/security_settings_models.dart';
import '../tdlib/tdlib_client.dart';
import '../tdlib/tdlib_json.dart';

/// Управление облачным паролем (2FA) в настройках.
class SecuritySettingsManager extends ChangeNotifier {
  SecuritySettingsManager({required TdlibClient client}) : _client = client;

  final TdlibClient _client;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  PasswordStateModel? _passwordState;
  var _isLoading = false;
  var _isSaving = false;
  String? _lastError;

  PasswordStateModel? get passwordState => _passwordState;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get lastError => _lastError;

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
    loadPasswordState();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void loadPasswordState() {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    _client.send({
      '@type': 'getPasswordState',
      '@extra': 'security_password_state',
    });
  }

  void setPassword({
    required String oldPassword,
    required String newPassword,
    required String hint,
    String recoveryEmail = '',
  }) {
    _isSaving = true;
    _lastError = null;
    notifyListeners();
    _client.send({
      '@type': 'setPassword',
      'old_password': oldPassword,
      'new_password': newPassword,
      'new_hint': hint,
      'set_recovery_email_address': recoveryEmail.isNotEmpty,
      'new_recovery_email_address': recoveryEmail,
      '@extra': 'security_set_password',
    });
  }

  void removePassword({required String oldPassword}) {
    setPassword(
      oldPassword: oldPassword,
      newPassword: '',
      hint: '',
    );
  }

  void _handleUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case 'passwordState':
        _handlePasswordState(update);
      case 'ok':
        _handleOk(update);
      case 'error':
        _handleError(update);
    }
  }

  void _handlePasswordState(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra != null &&
        extra != 'security_password_state' &&
        extra != 'security_set_password') {
      return;
    }

    _passwordState = PasswordStateModel(
      hasPassword: update['has_password'] as bool? ?? false,
      passwordHint: update['password_hint'] as String? ?? '',
      hasRecoveryEmail:
          update['has_recovery_email_address'] as bool? ?? false,
      recoveryEmailPattern:
          update['login_email_address_pattern'] as String? ?? '',
      pendingResetDate: tdIntOr(update['pending_reset_date']),
    );
    _isLoading = false;
    _isSaving = false;
    notifyListeners();
  }

  void _handleOk(Map<String, dynamic> update) {
    if (update['@extra'] != 'security_set_password') {
      return;
    }
    loadPasswordState();
  }

  void _handleError(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('security_')) {
      return;
    }
    _isLoading = false;
    _isSaving = false;
    _lastError = update['message'] as String? ?? 'Ошибка пароля';
    notifyListeners();
  }
}
