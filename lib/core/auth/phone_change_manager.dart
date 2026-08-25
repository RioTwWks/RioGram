import 'dart:async';

import 'package:flutter/foundation.dart';

import '../tdlib/tdlib_client.dart';

/// Смена номера телефона аккаунта.
class PhoneChangeManager extends ChangeNotifier {
  PhoneChangeManager({required TdlibClient client}) : _client = client;

  final TdlibClient _client;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  var _isSendingCode = false;
  var _isCheckingCode = false;
  String? _pendingPhoneNumber;
  String? _lastError;
  String? _codeInfoMessage;

  bool get isSendingCode => _isSendingCode;
  bool get isCheckingCode => _isCheckingCode;
  String? get pendingPhoneNumber => _pendingPhoneNumber;
  String? get lastError => _lastError;
  String? get codeInfoMessage => _codeInfoMessage;

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void requestChangeCode(String phoneNumber) {
    final normalized = phoneNumber.trim();
    if (normalized.isEmpty) {
      return;
    }

    _isSendingCode = true;
    _lastError = null;
    _codeInfoMessage = null;
    _pendingPhoneNumber = normalized;
    notifyListeners();

    _client.send({
      '@type': 'sendPhoneNumberCode',
      'phone_number': normalized,
      'settings': {
        '@type': 'phoneNumberAuthenticationSettings',
        'allow_flash_call': false,
        'allow_missed_call': false,
        'is_current_phone_number': false,
        'has_unknown_phone_number': false,
        'allow_sms_retriever_api': false,
        'authentication_tokens': <String>[],
      },
      'type': {'@type': 'phoneNumberCodeTypeChange'},
      '@extra': 'phone_change_send',
    });
  }

  void submitChangeCode(String code) {
    if (_pendingPhoneNumber == null) {
      return;
    }
    _isCheckingCode = true;
    _lastError = null;
    notifyListeners();
    _client.send({
      '@type': 'checkPhoneNumberCode',
      'code': code.trim(),
      '@extra': 'phone_change_check',
    });
  }

  void _handleUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case 'authenticationCodeInfo':
        _handleCodeInfo(update);
      case 'ok':
        _handleOk(update);
      case 'error':
        _handleError(update);
    }
  }

  void _handleCodeInfo(Map<String, dynamic> update) {
    if (update['@extra'] != 'phone_change_send') {
      return;
    }
    final type = update['type'] as Map<String, dynamic>?;
    _codeInfoMessage = switch (type?['@type']) {
      'authenticationCodeTypeTelegramMessage' =>
        'Код отправлен в Telegram',
      'authenticationCodeTypeSms' => 'Код отправлен по SMS',
      'authenticationCodeTypeCall' => 'Код будет продиктован звонком',
      _ => 'Код отправлен',
    };
    _isSendingCode = false;
    notifyListeners();
  }

  void _handleOk(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == 'phone_change_check') {
      _isCheckingCode = false;
      _pendingPhoneNumber = null;
      _codeInfoMessage = null;
      notifyListeners();
    }
  }

  void _handleError(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('phone_change_')) {
      return;
    }
    _isSendingCode = false;
    _isCheckingCode = false;
    _lastError = update['message'] as String? ?? 'Ошибка смены номера';
    notifyListeners();
  }
}
