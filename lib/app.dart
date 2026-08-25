import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/auth/account_manager.dart';
import 'core/auth/auth_manager.dart';
import 'core/auth/phone_change_manager.dart';
import 'core/auth/session_manager.dart';
import 'core/bot/bot_manager.dart';
import 'core/stories/story_manager.dart';
import 'core/secret/secret_chat_manager.dart';
import 'core/call/call_manager.dart';
import 'core/call/call_signaling_bridge.dart';
import 'core/call/group_call_manager.dart';
import 'core/chat/chat_manager.dart';
import 'core/chat/sticker_manager.dart';
import 'core/config/app_config.dart';
import 'core/integrations/external_integrations_manager.dart';
import 'core/features/anti_recall_store.dart';
import 'core/features/riogram_features_manager.dart';
import 'core/features/riogram_features_preferences.dart';
import 'core/locale/app_locale_manager.dart';
import 'core/notifications/notification_settings_manager.dart';
import 'core/privacy/privacy_settings_manager.dart';
import 'core/privacy/security_privacy_manager.dart';
import 'core/search/search_manager.dart';
import 'core/security/app_lock_manager.dart';
import 'core/security/security_settings_manager.dart';
import 'core/user/contact_manager.dart';
import 'core/user/profile_manager.dart';
import 'core/media/media_cache_manager.dart';
import 'core/notifications/notification_service.dart';
import 'core/proxy/proxy_manager.dart';
import 'core/proxy/web_proxy_manager.dart';
import 'core/theme/theme_manager.dart';
import 'core/theme/ui_customization_manager.dart';
import 'core/tdlib/tdlib_client.dart';
import 'models/auth_models.dart';
import 'screens/auth/code_screen.dart';
import 'screens/auth/email_auth_screen.dart';
import 'screens/auth/password_screen.dart';
import 'screens/auth/phone_screen.dart';
import 'screens/auth/qr_auth_screen.dart';
import 'screens/auth/registration_screen.dart';
import 'screens/chats/chats_screen.dart';
import 'widgets/app_lock_overlay.dart';
import 'widgets/call_overlay_host.dart';

class RioGramApp extends StatelessWidget {
  const RioGramApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return _BootstrapScope(config: config);
  }
}

class _BootstrapScope extends StatefulWidget {
  const _BootstrapScope({required this.config});

  final AppConfig config;

  @override
  State<_BootstrapScope> createState() => _BootstrapScopeState();
}

class _BootstrapScopeState extends State<_BootstrapScope> {
  late final UiCustomizationManager _uiCustomizationManager;
  late final ThemeManager _themeManager;
  late final AppLockManager _appLockManager;
  late final AccountManager _accountManager;
  var _scopeGeneration = 0;
  var _isBootstrapReady = false;

  @override
  void initState() {
    super.initState();
    _uiCustomizationManager = UiCustomizationManager();
    _themeManager = ThemeManager(customization: _uiCustomizationManager);
    _appLockManager = AppLockManager();
    _accountManager = AccountManager(
      onAccountChanged: () {
        setState(() => _scopeGeneration += 1);
      },
    );
    unawaited(_loadBootstrap());
  }

  Future<void> _loadBootstrap() async {
    await Future.wait([
      _themeManager.load(),
      _uiCustomizationManager.load(),
      _appLockManager.load(),
      _accountManager.load(),
    ]);
    if (!mounted) {
      return;
    }
    setState(() => _isBootstrapReady = true);
  }

  @override
  void dispose() {
    _themeManager.dispose();
    _appLockManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBootstrapReady) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UiCustomizationManager>.value(
          value: _uiCustomizationManager,
        ),
        ChangeNotifierProvider<ThemeManager>.value(value: _themeManager),
        ChangeNotifierProvider<AppLockManager>.value(value: _appLockManager),
        ChangeNotifierProvider<AccountManager>.value(value: _accountManager),
      ],
      child: KeyedSubtree(
        key: ValueKey(
          '${_accountManager.activeAccountId ?? 'default'}_$_scopeGeneration',
        ),
        child: _AppScope(
          config: widget.config,
          accountDirectorySuffix: _accountManager.directorySuffixFor(
            _accountManager.activeAccountId,
          ),
          child: Consumer2<ThemeManager, AppLockManager>(
            builder: (context, themeManager, appLock, _) {
              return MaterialApp(
                title: 'RioGram',
                theme: themeManager.lightTheme,
                darkTheme: themeManager.darkTheme,
                themeMode: themeManager.themeMode,
                home: AppLockOverlay(
                  child: const CallOverlayHost(
                    child: _AccountScopedApp(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AccountScopedApp extends StatelessWidget {
  const _AccountScopedApp();

  @override
  Widget build(BuildContext context) {
    return const _RootScreen();
  }
}

class _AppScope extends StatefulWidget {
  const _AppScope({
    required this.config,
    required this.accountDirectorySuffix,
    required this.child,
  });

  final AppConfig config;
  final String accountDirectorySuffix;
  final Widget child;

  @override
  State<_AppScope> createState() => _AppScopeState();
}

class _AppScopeState extends State<_AppScope> {
  late final TdlibClient _client;
  late final NotificationService _notificationService;
  ProxyManager? _proxyManager;
  WebProxyManager? _webProxyManager;
  late final AuthManager _authManager;
  late final MediaCacheManager _mediaCacheManager;
  late final StickerManager _stickerManager;
  late final CallManager _callManager;
  late final GroupCallManager _groupCallManager;
  late final CallSignalingBridge _callSignalingBridge;
  late final ContactManager _contactManager;
  late final ProfileManager _profileManager;
  late final SearchManager _searchManager;
  late final NotificationSettingsManager _notificationSettingsManager;
  late final PrivacySettingsManager _privacySettingsManager;
  late final SecurityPrivacyManager _securityPrivacyManager;
  late final SecuritySettingsManager _securitySettingsManager;
  late final SessionManager _sessionManager;
  late final PhoneChangeManager _phoneChangeManager;
  late final AppLocaleManager _appLocaleManager;
  late final BotManager _botManager;
  late final SecretChatManager _secretChatManager;
  late final StoryManager _storyManager;
  late final ExternalIntegrationsManager _externalIntegrationsManager;
  late final ChatManager _chatManager;
  late final GhostModeManager _ghostModeManager;
  late final RioGramMediaFeaturesManager _mediaFeaturesManager;
  late final AntiRecallStore _antiRecallStore;
  late final MessageTranslator _messageTranslator;
  late final RioGramFeaturesPreferences _featuresPreferences;

  @override
  void initState() {
    super.initState();
    _client = TdlibClient();
    _notificationService = NotificationService()..init();

    if (kIsWeb) {
      _webProxyManager = WebProxyManager(client: _client);
    } else {
      _proxyManager = ProxyManager(client: _client, config: widget.config);
    }

    _mediaCacheManager = MediaCacheManager(client: _client);
    _stickerManager = StickerManager(client: _client);
    _callSignalingBridge = WebRtcCallSignalingBridge();
    _callManager = CallManager(
      client: _client,
      signalingBridge: _callSignalingBridge,
    );
    _groupCallManager = GroupCallManager(
      client: _client,
      signalingBridge: _callSignalingBridge,
    );
    _contactManager = ContactManager(client: _client);
    _profileManager = ProfileManager(client: _client);
    _securityPrivacyManager = SecurityPrivacyManager(client: _client);
    _externalIntegrationsManager = ExternalIntegrationsManager(client: _client);
    _searchManager = SearchManager(
      client: _client,
      securityPrivacy: _securityPrivacyManager,
    );
    _notificationSettingsManager = NotificationSettingsManager(
      client: _client,
      onBadgeCountChanged: (count) {
        _notificationService.updateBadgeCount(count);
      },
    );
    _privacySettingsManager = PrivacySettingsManager(client: _client);
    _securitySettingsManager = SecuritySettingsManager(client: _client);
    _sessionManager = SessionManager(client: _client);
    _phoneChangeManager = PhoneChangeManager(client: _client);
    _appLocaleManager = AppLocaleManager(client: _client)..load();
    _botManager = BotManager(client: _client);
    _secretChatManager = SecretChatManager(client: _client);
    _storyManager = StoryManager(
      client: _client,
      mediaCache: _mediaCacheManager,
    );

    _featuresPreferences = RioGramFeaturesPreferences();
    _ghostModeManager = GhostModeManager(
      client: _client,
      preferences: _featuresPreferences,
    );
    _mediaFeaturesManager = RioGramMediaFeaturesManager(
      preferences: _featuresPreferences,
    );
    _antiRecallStore = AntiRecallStore(
      accountSuffix: widget.accountDirectorySuffix,
    );
    _messageTranslator = MessageTranslator(client: _client);

    unawaited(_loadFeatureSettings());

    _chatManager = ChatManager(
      client: _client,
      notificationService: _notificationService,
      notificationSettings: _notificationSettingsManager,
      mediaCache: _mediaCacheManager,
      ghostMode: _ghostModeManager,
      antiRecallStore: _antiRecallStore,
      mediaFeatures: _mediaFeaturesManager,
      securityPrivacy: _securityPrivacyManager,
      externalIntegrations: _externalIntegrationsManager,
    );

    _profileManager.addListener(_registerAccountIfNeeded);

    _authManager = AuthManager(
      client: _client,
      config: widget.config,
      proxyManager: _proxyManager,
      webProxyManager: _webProxyManager,
      accountDirectorySuffix: widget.accountDirectorySuffix.isEmpty
          ? null
          : widget.accountDirectorySuffix,
      onAuthorized: _onAuthorized,
    );
  }

  Future<void> _loadFeatureSettings() async {
    await Future.wait([
      _ghostModeManager.load(),
      _mediaFeaturesManager.load(),
      _antiRecallStore.load(),
      _securityPrivacyManager.load(),
      _externalIntegrationsManager.load(),
    ]);
  }

  void _onAuthorized() {
    _ghostModeManager.onAuthorized();
    _securityPrivacyManager.onAuthorized();
    _messageTranslator.startListening();
    _appLocaleManager.startListening();
    _mediaCacheManager.startListening();
    _stickerManager.startListening();
    _callManager.startListening();
    _groupCallManager.startListening();
    _contactManager.startListening();
    _profileManager.startListening();
    _searchManager.startListening();
    _notificationSettingsManager.startListening();
    _privacySettingsManager.startListening();
    _securityPrivacyManager.startListening();
    _securitySettingsManager.startListening();
    _sessionManager.startListening();
    _phoneChangeManager.startListening();
    _botManager.startListening();
    _secretChatManager.startListening();
    _storyManager.startListening();
    _storyManager.setSavedMessagesChatId(_chatManager.savedMessagesChatId);
    _storyManager.loadMainStoryList();
    _profileManager.loadOwnProfile();
    _contactManager.loadContacts();
    _chatManager.startListening();
    _chatManager.loadChats();
    _registerAccountIfNeeded();
  }

  void _registerAccountIfNeeded() {
    if (!mounted) {
      return;
    }
    final user = _profileManager.ownUser;
    if (user == null) {
      return;
    }
    final accountManager = context.read<AccountManager>();
    accountManager.upsertCurrentAccount(
      userId: user.id,
      phoneNumber: _authManager.phoneNumber ?? user.phoneNumber,
      displayName: user.displayName,
    );
  }

  @override
  void dispose() {
    _profileManager.removeListener(_registerAccountIfNeeded);
    _authManager.dispose();
    _chatManager.dispose();
    _groupCallManager.dispose();
    _callManager.dispose();
    _contactManager.dispose();
    _profileManager.dispose();
    _searchManager.dispose();
    _notificationSettingsManager.dispose();
    _privacySettingsManager.dispose();
    _securityPrivacyManager.dispose();
    _externalIntegrationsManager.dispose();
    _securitySettingsManager.dispose();
    _sessionManager.dispose();
    _phoneChangeManager.dispose();
    _appLocaleManager.dispose();
    _botManager.dispose();
    _secretChatManager.dispose();
    _storyManager.dispose();
    _messageTranslator.dispose();
    _stickerManager.dispose();
    _mediaCacheManager.dispose();
    _proxyManager?.dispose();
    _webProxyManager?.dispose();
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TdlibClient>.value(value: _client),
        ChangeNotifierProvider<AuthManager>.value(value: _authManager),
        ChangeNotifierProvider<ChatManager>.value(value: _chatManager),
        ChangeNotifierProvider<MediaCacheManager>.value(
          value: _mediaCacheManager,
        ),
        ChangeNotifierProvider<StickerManager>.value(
          value: _stickerManager,
        ),
        ChangeNotifierProvider<CallManager>.value(
          value: _callManager,
        ),
        ChangeNotifierProvider<GroupCallManager>.value(
          value: _groupCallManager,
        ),
        ChangeNotifierProvider<ContactManager>.value(
          value: _contactManager,
        ),
        ChangeNotifierProvider<ProfileManager>.value(
          value: _profileManager,
        ),
        ChangeNotifierProvider<SearchManager>.value(
          value: _searchManager,
        ),
        ChangeNotifierProvider<NotificationSettingsManager>.value(
          value: _notificationSettingsManager,
        ),
        ChangeNotifierProvider<PrivacySettingsManager>.value(
          value: _privacySettingsManager,
        ),
        ChangeNotifierProvider<SecurityPrivacyManager>.value(
          value: _securityPrivacyManager,
        ),
        ChangeNotifierProvider<ExternalIntegrationsManager>.value(
          value: _externalIntegrationsManager,
        ),
        ChangeNotifierProvider<SecuritySettingsManager>.value(
          value: _securitySettingsManager,
        ),
        ChangeNotifierProvider<SessionManager>.value(
          value: _sessionManager,
        ),
        ChangeNotifierProvider<PhoneChangeManager>.value(
          value: _phoneChangeManager,
        ),
        ChangeNotifierProvider<AppLocaleManager>.value(
          value: _appLocaleManager,
        ),
        ChangeNotifierProvider<BotManager>.value(
          value: _botManager,
        ),
        ChangeNotifierProvider<SecretChatManager>.value(
          value: _secretChatManager,
        ),
        ChangeNotifierProvider<StoryManager>.value(
          value: _storyManager,
        ),
        ChangeNotifierProvider<GhostModeManager>.value(
          value: _ghostModeManager,
        ),
        ChangeNotifierProvider<RioGramMediaFeaturesManager>.value(
          value: _mediaFeaturesManager,
        ),
        ChangeNotifierProvider<AntiRecallStore>.value(
          value: _antiRecallStore,
        ),
        ChangeNotifierProvider<MessageTranslator>.value(
          value: _messageTranslator,
        ),
        if (_proxyManager != null)
          ChangeNotifierProvider<ProxyManager>.value(value: _proxyManager!),
        if (_webProxyManager != null)
          ChangeNotifierProvider<WebProxyManager>.value(
            value: _webProxyManager!,
          ),
      ],
      child: widget.child,
    );
  }
}

class _RootScreen extends StatefulWidget {
  const _RootScreen();

  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthManager>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthManager>();

    return switch (auth.phase) {
      AuthPhase.initializing => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthPhase.waitPhoneNumber => const PhoneScreen(),
      AuthPhase.waitQrConfirmation => const QrAuthScreen(),
      AuthPhase.waitRegistration => const RegistrationScreen(),
      AuthPhase.waitEmailAddress => const EmailAuthScreen(),
      AuthPhase.waitEmailCode => const EmailAuthScreen(isCodeStep: true),
      AuthPhase.waitCode => const CodeScreen(),
      AuthPhase.waitPassword => const PasswordScreen(),
      AuthPhase.ready => const ChatsScreen(),
      AuthPhase.error => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    auth.errorMessage ?? 'Ошибка инициализации',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: auth.initialize,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ),
    };
  }
}
