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

  static const Duration authRequestTimeout = Duration(seconds: 45);
  static const Duration initTimeout = Duration(seconds: 30);

  final TdlibClient _client;
  final AppConfig _config;
  final ProxyManager? _proxyManager;
  final VoidCallback? onAuthorized;

  AuthPhase _phase = AuthPhase.initializing;
  String? _errorMessage;
  String? _phoneNumber;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  bool _isInitializing = false;
  bool _isAuthRequestInProgress = false;
  bool _initialized = false;
  Timer? _authTimeoutTimer;

  AuthPhase get phase => _phase;
  String? get errorMessage => _errorMessage;
  String? get phoneNumber => _phoneNumber;
  bool get isAuthRequestInProgress => _isAuthRequestInProgress;

  TdlibClient get client => _client;

  Future<void> initialize() async {
    if (_isInitializing) {
      return;
    }

    _isInitializing = true;
    _phase = AuthPhase.initializing;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!_initialized) {
        await _client.ensureClient();
        _subscription?.cancel();
        _subscription = _client.updates.listen(_handleUpdate);
        await _client.configure(_config);

        final proxyManager = _proxyManager;
        if (proxyManager != null) {
          await proxyManager.setupProxies();
          if (!proxyManager.hasActiveProxy) {
            throw StateError(
              proxyManager.lastError ??
                  'Прокси недоступен. Проверьте VPS, порт и secret в .env',
            );
          }
        }

        final authReady = _waitForAuthorizationState(
          'authorizationStateWaitPhoneNumber',
          timeout: initTimeout,
        );

        // Состояние могло прийти во время setupProxies — тогда _phase уже обновлён.
        final isReady = _phase == AuthPhase.waitPhoneNumber ||
            _phase == AuthPhase.waitCode ||
            _phase == AuthPhase.waitPassword ||
            _phase == AuthPhase.ready ||
            await authReady;
        if (!isReady && _phase == AuthPhase.initializing) {
          throw StateError(
            'TDLib не готов к авторизации. Проверьте API-ключи и прокси.',
          );
        }

        _initialized = true;
      }
    } catch (error) {
      _phase = AuthPhase.error;
      _errorMessage = error.toString().replaceFirst('StateError: ', '');
      notifyListeners();
    } finally {
      _isInitializing = false;
    }
  }

  void submitPhoneNumber(String phoneNumber) {
    if (_isAuthRequestInProgress || _phase != AuthPhase.waitPhoneNumber) {
      return;
    }

    _beginAuthRequest();
    _phoneNumber = phoneNumber.trim();

    _client.send({
      '@type': 'setAuthenticationPhoneNumber',
      'phone_number': _phoneNumber,
      'settings': {
        '@type': 'phoneNumberAuthenticationSettings',
        'allow_flash_call': false,
        'allow_missed_call': false,
        'is_current_phone_number': false,
        'has_unknown_phone_number': false,
        'allow_sms_retriever_api': false,
        'authentication_tokens': <String>[],
      },
    });
  }

  void submitCode(String code) {
    if (_isAuthRequestInProgress || _phase != AuthPhase.waitCode) {
      return;
    }

    _beginAuthRequest();
    _client.send({
      '@type': 'checkAuthenticationCode',
      'code': code.trim(),
    });
  }

  void submitPassword(String password) {
    if (_isAuthRequestInProgress || _phase != AuthPhase.waitPassword) {
      return;
    }

    _beginAuthRequest();
    _client.send({
      '@type': 'checkAuthenticationPassword',
      'password': password,
    });
  }

  void logOut() {
    _client.send({'@type': 'logOut'});
  }

  void _beginAuthRequest() {
    _isAuthRequestInProgress = true;
    _errorMessage = null;
    notifyListeners();

    _authTimeoutTimer?.cancel();
    _authTimeoutTimer = Timer(authRequestTimeout, () {
      if (!_isAuthRequestInProgress) {
        return;
      }
      _isAuthRequestInProgress = false;
      _phase = AuthPhase.error;
      _errorMessage =
          'Таймаут запроса (${authRequestTimeout.inSeconds} с). '
          'Проверьте, что PhantomProxy/StealthGate запущены на VPS и доступны '
          'по адресам из .env (в релизных сборках они вшиты при сборке).';
      notifyListeners();
    });
  }

  void _handleUpdate(Map<String, dynamic> update) {
    final type = update['@type'];

    switch (type) {
      case 'updateAuthorizationState':
        _handleAuthorizationState(
          update['authorization_state'] as Map<String, dynamic>,
        );
      case 'error':
        final extra = update['@extra'] as String?;
        if (extra != null &&
            (extra.startsWith('ping_') || extra.startsWith('addProxy_'))) {
          break;
        }

        final message = update['message'] as String? ?? 'Неизвестная ошибка TDLib';
        if (_isBenignAuthError(message)) {
          break;
        }

        _authTimeoutTimer?.cancel();
        _isAuthRequestInProgress = false;
        _phase = AuthPhase.error;
        _errorMessage = message;
        notifyListeners();
    }
  }

  bool _isBenignAuthError(String message) {
    return message == 'Another authorization query has started';
  }

  void _handleAuthorizationState(Map<String, dynamic> state) {
    _authTimeoutTimer?.cancel();
    _isAuthRequestInProgress = false;
    _errorMessage = null;

    switch (state['@type']) {
      case 'authorizationStateWaitPhoneNumber':
        _phase = AuthPhase.waitPhoneNumber;
      case 'authorizationStateWaitCode':
        _phase = AuthPhase.waitCode;
      case 'authorizationStateWaitPassword':
        _phase = AuthPhase.waitPassword;
      case 'authorizationStateWaitOtherDeviceConfirmation':
        _phase = AuthPhase.waitCode;
        _errorMessage =
            'Код отправлен в Telegram на другом устройстве. '
            'Откройте официальный клиент или дождитесь SMS.';
      case 'authorizationStateWaitEmailAddress':
      case 'authorizationStateWaitEmailCode':
        _phase = AuthPhase.error;
        _errorMessage =
            'Telegram запросил e-mail для входа. '
            'Пока поддерживается только вход по номеру телефона.';
      case 'authorizationStateWaitRegistration':
        _phase = AuthPhase.error;
        _errorMessage = 'Требуется регистрация нового аккаунта в Telegram.';
      case 'authorizationStateReady':
        _phase = AuthPhase.ready;
        onAuthorized?.call();
      case 'authorizationStateClosing':
      case 'authorizationStateClosed':
        _phase = AuthPhase.waitPhoneNumber;
    }
    notifyListeners();
  }

  Future<bool> _waitForAuthorizationState(
    String expectedState, {
    required Duration timeout,
  }) {
    return _client
        .waitFor(
          predicate: (update) {
            if (update['@type'] != 'updateAuthorizationState') {
              return false;
            }
            final state = update['authorization_state'] as Map<String, dynamic>?;
            return state?['@type'] == expectedState;
          },
          timeout: timeout,
        )
        .then((update) => update != null);
  }

  @override
  void dispose() {
    _authTimeoutTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
