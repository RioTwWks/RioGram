import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../proxy/proxy_manager.dart';
import '../proxy/web_proxy_manager.dart';
import '../tdlib/tdlib_client.dart';
import '../tdlib/web/tdlib_js_bridge.dart';
import '../tdlib/web/tdweb_storage_recovery.dart';
import '../../models/auth_models.dart';
import 'auth_state_predicates.dart';

/// Управление авторизацией через TDLib.
class AuthManager extends ChangeNotifier {
  AuthManager({
    required TdlibClient client,
    required AppConfig config,
    ProxyManager? proxyManager,
    WebProxyManager? webProxyManager,
    this.accountDirectorySuffix,
    this.onAuthorized,
    this.onLoggedOut,
  })  : _client = client,
        _config = config,
        _proxyManager = proxyManager,
        _webProxyManager = webProxyManager;

  static const Duration authRequestTimeout = Duration(seconds: 45);
  static Duration get initTimeout =>
      kIsWeb ? const Duration(seconds: 90) : const Duration(seconds: 30);

  final TdlibClient _client;
  final AppConfig _config;
  final ProxyManager? _proxyManager;
  final WebProxyManager? _webProxyManager;
  final String? accountDirectorySuffix;
  final VoidCallback? onAuthorized;
  final VoidCallback? onLoggedOut;

  AuthPhase _phase = AuthPhase.initializing;
  String? _errorMessage;
  String? _phoneNumber;
  String? _qrConfirmationLink;
  RegistrationTerms? _registrationTerms;
  String? _pendingEmailAddress;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  bool _isInitializing = false;
  bool _isAuthRequestInProgress = false;
  bool _initialized = false;
  String? _lastAuthorizationState;
  Timer? _authTimeoutTimer;

  AuthPhase get phase => _phase;
  String? get errorMessage => _errorMessage;
  String? get phoneNumber => _phoneNumber;
  String? get qrConfirmationLink => _qrConfirmationLink;
  RegistrationTerms? get registrationTerms => _registrationTerms;
  String? get pendingEmailAddress => _pendingEmailAddress;
  bool get isAuthRequestInProgress => _isAuthRequestInProgress;

  bool get canResetWebStorage =>
      kIsWeb && isTdlibDatabaseCorruptionMessage(_errorMessage);

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
      if (_initialized) {
        _client.send({
          '@type': 'getAuthorizationState',
          '@extra': 'auth_getState',
        });
        return;
      }

      final webProxyManager = _webProxyManager;
      if (webProxyManager != null) {
        await webProxyManager.setup();
        if (webProxyManager.lastError != null) {
          debugPrint(
            'AuthManager: WSS proxy warning: ${webProxyManager.lastError}',
          );
        }
      }

      if (!_config.hasApiCredentials) {
        throw StateError(
          'TELEGRAM_API_ID / TELEGRAM_API_HASH не загружены из .env',
        );
      }

      _subscription?.cancel();
      _subscription = _client.updates.listen(_handleUpdate);
      await _client.ensureClient();

      final initialUpdate = _client.takeInitialAuthorizationUpdate();
      if (initialUpdate != null) {
        _handleUpdate(initialUpdate);
      }

      final proxyManager = _proxyManager;
      if (proxyManager != null) {
        await proxyManager.setupProxies();
        if (!proxyManager.hasActiveProxy && proxyManager.proxies.isEmpty) {
          throw StateError(
            proxyManager.lastError ??
                'Прокси недоступен. Проверьте VPS, порт и secret в .env',
          );
        }
        if (proxyManager.lastError != null) {
          debugPrint('AuthManager: proxy warning: ${proxyManager.lastError}');
        }
      }

      await _applyTdlibParametersWhenReady();

      final authReady = _waitForInteractiveAuthorization(
        timeout: initTimeout,
      );

      final isReady =
          _isInteractiveAuthPhase(_phase) || await authReady;
      if (!isReady && _phase == AuthPhase.initializing) {
        final stateHint = _lastAuthorizationState != null
            ? ' Последнее состояние: $_lastAuthorizationState.'
            : '';
        throw StateError(
          'TDLib не готов к авторизации. Проверьте API-ключи и прокси.$stateHint',
        );
      }

      _initialized = true;
    } catch (error) {
      _phase = AuthPhase.error;
      _errorMessage = formatAuthErrorMessage(
        error
            .toString()
            .replaceFirst(RegExp(r'^(StateError|Bad state): '), ''),
      );
      notifyListeners();
    } finally {
      _isInitializing = false;
    }
  }

  /// Сбрасывает IndexedDB tdweb и пересоздаёт клиент (после CRC/binlog ошибок).
  Future<void> resetWebStorageAndInitialize() async {
    if (!kIsWeb || _isInitializing) {
      return;
    }

    _isInitializing = true;
    _phase = AuthPhase.initializing;
    _errorMessage = null;
    notifyListeners();

    try {
      await TdlibJsBridge.clearWebStorage();
      _initialized = false;
      await _client.resetForStorageClear();
    } catch (error) {
      _phase = AuthPhase.error;
      _errorMessage = formatAuthErrorMessage(error.toString());
      notifyListeners();
    } finally {
      _isInitializing = false;
    }

    if (_phase != AuthPhase.error) {
      await initialize();
    }
  }

  bool _isInteractiveAuthPhase(AuthPhase phase) {
    return switch (phase) {
      AuthPhase.waitPhoneNumber ||
      AuthPhase.waitCode ||
      AuthPhase.waitPassword ||
      AuthPhase.waitQrConfirmation ||
      AuthPhase.waitRegistration ||
      AuthPhase.waitEmailAddress ||
      AuthPhase.waitEmailCode ||
      AuthPhase.ready =>
        true,
      _ => false,
    };
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

  void requestQrCodeAuthentication() {
    if (_isAuthRequestInProgress || _phase != AuthPhase.waitPhoneNumber) {
      return;
    }

    _beginAuthRequest();
    _client.send({
      '@type': 'requestQrCodeAuthentication',
      'other_user_ids': <int>[],
      '@extra': 'auth_qr_request',
    });
  }

  void submitCode(String code) {
    if (_isAuthRequestInProgress ||
        (_phase != AuthPhase.waitCode && _phase != AuthPhase.waitEmailCode)) {
      return;
    }

    _beginAuthRequest();
    if (_phase == AuthPhase.waitEmailCode) {
      _client.send({
        '@type': 'checkAuthenticationEmailCode',
        'code': {
          '@type': 'emailAddressAuthenticationCode',
          'code': code.trim(),
        },
      });
      return;
    }

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

  void submitEmailAddress(String email) {
    if (_isAuthRequestInProgress || _phase != AuthPhase.waitEmailAddress) {
      return;
    }

    _beginAuthRequest();
    _pendingEmailAddress = email.trim();
    _client.send({
      '@type': 'setAuthenticationEmailAddress',
      'email_address': _pendingEmailAddress,
    });
  }

  void registerUser({
    required String firstName,
    required String lastName,
    bool disableNotification = false,
  }) {
    if (_isAuthRequestInProgress || _phase != AuthPhase.waitRegistration) {
      return;
    }

    _beginAuthRequest();
    _client.send({
      '@type': 'registerUser',
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'disable_notification': disableNotification,
    });
  }

  void resendAuthenticationCode() {
    if (_isAuthRequestInProgress) {
      return;
    }
    _client.send({
      '@type': 'resendAuthenticationCode',
      'reason': null,
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
      final proxyManager = _proxyManager;
      final systemProxy = proxyManager?.systemProxy;
      final systemHint = systemProxy != null && systemProxy.isConfigured
          ? ' Системный прокси: ${systemProxy.host}:${systemProxy.port}.'
          : '';
      _errorMessage =
          'Таймаут запроса (${authRequestTimeout.inSeconds} с).$systemHint '
          'Проверьте PhantomProxy/StealthGate на VPS и доступность портов '
          '15443/14443 (в релизе — адреса из .env).';
      notifyListeners();
    });
  }

  void _handleUpdate(Map<String, dynamic> update) {
    final type = update['@type'];

    switch (type) {
      case 'updateFatalError':
        _authTimeoutTimer?.cancel();
        _isAuthRequestInProgress = false;
        _phase = AuthPhase.error;
        _errorMessage = formatAuthErrorMessage(
          update['error'] as String? ??
              'Фатальная ошибка TDLib (WebAssembly)',
        );
        notifyListeners();
        return;
      case 'updateAuthorizationState':
        _handleAuthorizationState(
          update['authorization_state'] as Map<String, dynamic>,
        );
      case 'authorizationStateWaitPhoneNumber':
      case 'authorizationStateWaitCode':
      case 'authorizationStateWaitPassword':
      case 'authorizationStateWaitOtherDeviceConfirmation':
      case 'authorizationStateWaitEmailAddress':
      case 'authorizationStateWaitEmailCode':
      case 'authorizationStateWaitRegistration':
      case 'authorizationStateReady':
      case 'authorizationStateClosing':
      case 'authorizationStateClosed':
        if (update['@extra'] == 'auth_getState') {
          _handleAuthorizationState(update);
        }
      case 'error':
        final extra = update['@extra'] as String?;
        if (!_shouldTreatAsAuthError(extra)) {
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

  bool _shouldTreatAsAuthError(String? extra) {
    if (_phase == AuthPhase.ready) {
      return false;
    }
    if (extra == null) {
      return true;
    }
    if (extra == 'auth_getState' || extra == 'auth_qr_request') {
      return true;
    }
    const nonAuthPrefixes = [
      'ping_',
      'addProxy_',
      'enableProxy_',
      'disableProxy_',
      'openChat_',
      'getChatHistory_',
      'getChatHistoryLocal_',
      'forumTopicHistory_',
      'forumTopics_',
      'viewMessages_',
      'chatInfo_',
      'messageThread_',
      'searchChats_',
      'searchMessages_',
      'newChatSearch_',
      'newChatSearchLocal_',
      'newChatPublic_',
      'autoDownloadPresets_',
      'storageStats_',
      'optimizeStorage_',
      'createSupergroup_',
      'createBasicGroup_',
      'upgradeBasicGroup_',
      'joinChat_',
      'joinInvite_',
      'createPrivateChat_',
      'createForumTopic_',
      'story_load_',
      'story_active_',
      'story_get_',
      'story_open_',
      'story_close_',
      'story_post_',
      'story_reaction_',
      'story_reply_',
      'story_chat_',
      'story_reactions',
      'story_can_post_',
      'sessions_',
      'phone_change_',
    ];
    for (final prefix in nonAuthPrefixes) {
      if (extra.startsWith(prefix)) {
        return false;
      }
    }
    return true;
  }

  bool _isBenignAuthError(String message) {
    return message == 'Another authorization query has started';
  }

  void _handleAuthorizationState(Map<String, dynamic> state) {
    _authTimeoutTimer?.cancel();
    _isAuthRequestInProgress = false;
    _errorMessage = null;
    _lastAuthorizationState = state['@type'] as String?;

    switch (state['@type']) {
      case 'authorizationStateWaitPhoneNumber':
        _phase = AuthPhase.waitPhoneNumber;
        _qrConfirmationLink = null;
      case 'authorizationStateWaitCode':
        _phase = AuthPhase.waitCode;
      case 'authorizationStateWaitPassword':
        _phase = AuthPhase.waitPassword;
      case 'authorizationStateWaitOtherDeviceConfirmation':
        _phase = AuthPhase.waitQrConfirmation;
        _qrConfirmationLink = state['link'] as String?;
      case 'authorizationStateWaitEmailAddress':
        _phase = AuthPhase.waitEmailAddress;
      case 'authorizationStateWaitEmailCode':
        _phase = AuthPhase.waitEmailCode;
      case 'authorizationStateWaitRegistration':
        _phase = AuthPhase.waitRegistration;
        _registrationTerms = RegistrationTerms.fromTdlib(
          state['terms_of_service'] as Map<String, dynamic>?,
        );
      case 'authorizationStateReady':
        _phase = AuthPhase.ready;
        _qrConfirmationLink = null;
        onAuthorized?.call();
      case 'authorizationStateClosing':
        _phase = AuthPhase.waitPhoneNumber;
      case 'authorizationStateClosed':
        _phase = AuthPhase.waitPhoneNumber;
        _qrConfirmationLink = null;
        _registrationTerms = null;
        _pendingEmailAddress = null;
        onLoggedOut?.call();
    }
    notifyListeners();
  }

  Future<void> _applyTdlibParametersWhenReady() async {
    if (_isInteractiveAuthPhase(_phase)) {
      return;
    }

    var state = _lastAuthorizationState ?? _client.initialAuthorizationState;
    if (state == 'authorizationStateWaitTdlibParameters') {
      await _client.configure(
        _config,
        accountDirectorySuffix: accountDirectorySuffix,
      );
      return;
    }

    if (isPastTdlibParametersStage(state)) {
      return;
    }

    final paramsState = await _client.waitFor(
      predicate: isTdlibParametersStageUpdate,
      timeout: initTimeout,
    );
    state = paramsState != null
        ? authorizationStateType(paramsState)
        : (_lastAuthorizationState ?? _client.initialAuthorizationState);

    if (state == 'authorizationStateWaitTdlibParameters') {
      await _client.configure(
        _config,
        accountDirectorySuffix: accountDirectorySuffix,
      );
      return;
    }

    if (isPastTdlibParametersStage(state)) {
      return;
    }

    if (state == null) {
      _client.send({
        '@type': 'getAuthorizationState',
        '@extra': 'auth_getState',
      });
      final stateUpdate = await _client.waitFor(
        predicate: (update) => authorizationStateType(update) != null,
        timeout: initTimeout,
      );
      state = stateUpdate != null
          ? authorizationStateType(stateUpdate)
          : (_lastAuthorizationState ?? _client.initialAuthorizationState);

      if (state == 'authorizationStateWaitTdlibParameters') {
        await _client.configure(
          _config,
          accountDirectorySuffix: accountDirectorySuffix,
        );
        return;
      }
      if (isPastTdlibParametersStage(state)) {
        return;
      }
    }

    throw StateError(
      'Неожиданное состояние TDLib: ${state ?? 'none'}',
    );
  }

  Future<bool> _waitForInteractiveAuthorization({
    required Duration timeout,
  }) async {
    if (_isInteractiveAuthPhase(_phase)) {
      return true;
    }

    final update = await _client.waitFor(
      predicate: isInteractiveAuthorizationUpdate,
      timeout: timeout,
    );
    return update != null;
  }

  @override
  void dispose() {
    _authTimeoutTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
