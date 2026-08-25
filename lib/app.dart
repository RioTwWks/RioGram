import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/auth/auth_manager.dart';
import 'core/bot/bot_manager.dart';
import 'core/secret/secret_chat_manager.dart';
import 'core/call/call_manager.dart';
import 'core/call/call_signaling_bridge.dart';
import 'core/call/group_call_manager.dart';
import 'core/chat/chat_manager.dart';
import 'core/chat/sticker_manager.dart';
import 'core/config/app_config.dart';
import 'core/locale/app_locale_manager.dart';
import 'core/notifications/notification_settings_manager.dart';
import 'core/privacy/privacy_settings_manager.dart';
import 'core/search/search_manager.dart';
import 'core/security/security_settings_manager.dart';
import 'core/user/contact_manager.dart';
import 'core/user/profile_manager.dart';
import 'core/media/media_cache_manager.dart';
import 'core/notifications/notification_service.dart';
import 'core/proxy/proxy_manager.dart';
import 'core/theme/theme_manager.dart';
import 'core/tdlib/tdlib_client.dart';
import 'models/auth_models.dart';
import 'screens/auth/code_screen.dart';
import 'screens/auth/password_screen.dart';
import 'screens/auth/phone_screen.dart';
import 'screens/chats/chats_screen.dart';
import 'widgets/call_overlay_host.dart';

class RioGramApp extends StatelessWidget {
  const RioGramApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return _AppScope(
      config: config,
      child: Consumer<ThemeManager>(
        builder: (context, themeManager, _) {
          if (!themeManager.isLoaded) {
            return const MaterialApp(
              home: Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          return MaterialApp(
            title: 'RioGram',
            theme: themeManager.lightTheme,
            darkTheme: themeManager.darkTheme,
            themeMode: themeManager.themeMode,
            home: const CallOverlayHost(
              child: _RootScreen(),
            ),
          );
        },
      ),
    );
  }
}

class _AppScope extends StatefulWidget {
  const _AppScope({required this.config, required this.child});

  final AppConfig config;
  final Widget child;

  @override
  State<_AppScope> createState() => _AppScopeState();
}

class _AppScopeState extends State<_AppScope> {
  late final TdlibClient _client;
  late final ThemeManager _themeManager;
  late final NotificationService _notificationService;
  ProxyManager? _proxyManager;
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
  late final SecuritySettingsManager _securitySettingsManager;
  late final AppLocaleManager _appLocaleManager;
  late final BotManager _botManager;
  late final SecretChatManager _secretChatManager;
  late final ChatManager _chatManager;

  @override
  void initState() {
    super.initState();
    _client = TdlibClient();
    _themeManager = ThemeManager()..load();
    _notificationService = NotificationService()..init();

    _proxyManager = ProxyManager(client: _client, config: widget.config);

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
    _searchManager = SearchManager(client: _client);
    _notificationSettingsManager = NotificationSettingsManager(
      client: _client,
      onBadgeCountChanged: (count) {
        _notificationService.updateBadgeCount(count);
      },
    );
    _privacySettingsManager = PrivacySettingsManager(client: _client);
    _securitySettingsManager = SecuritySettingsManager(client: _client);
    _appLocaleManager = AppLocaleManager(client: _client)..load();
    _botManager = BotManager(client: _client);
    _secretChatManager = SecretChatManager(client: _client);

    _chatManager = ChatManager(
      client: _client,
      notificationService: _notificationService,
      notificationSettings: _notificationSettingsManager,
      mediaCache: _mediaCacheManager,
    );

    _authManager = AuthManager(
      client: _client,
      config: widget.config,
      proxyManager: _proxyManager,
      onAuthorized: () {
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
        _securitySettingsManager.startListening();
        _botManager.startListening();
        _secretChatManager.startListening();
        _profileManager.loadOwnProfile();
        _contactManager.loadContacts();
        _chatManager.startListening();
        _chatManager.loadChats();
      },
    );
  }

  @override
  void dispose() {
    _authManager.dispose();
    _chatManager.dispose();
    _groupCallManager.dispose();
    _callManager.dispose();
    _contactManager.dispose();
    _profileManager.dispose();
    _searchManager.dispose();
    _notificationSettingsManager.dispose();
    _privacySettingsManager.dispose();
    _securitySettingsManager.dispose();
    _appLocaleManager.dispose();
    _botManager.dispose();
    _secretChatManager.dispose();
    _stickerManager.dispose();
    _mediaCacheManager.dispose();
    _proxyManager?.dispose();
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TdlibClient>.value(value: _client),
        ChangeNotifierProvider<ThemeManager>.value(value: _themeManager),
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
        ChangeNotifierProvider<SecuritySettingsManager>.value(
          value: _securitySettingsManager,
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
        if (_proxyManager != null)
          ChangeNotifierProvider<ProxyManager>.value(value: _proxyManager!),
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
