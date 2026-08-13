import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/auth/auth_manager.dart';
import 'core/chat/chat_manager.dart';
import 'core/config/app_config.dart';
import 'core/notifications/notification_service.dart';
import 'core/proxy/proxy_manager.dart';
import 'core/theme/theme_manager.dart';
import 'core/tdlib/tdlib_client.dart';
import 'models/auth_models.dart';
import 'screens/auth/code_screen.dart';
import 'screens/auth/password_screen.dart';
import 'screens/auth/phone_screen.dart';
import 'screens/chats/chats_screen.dart';

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
            home: const _RootScreen(),
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
  late final ChatManager _chatManager;

  @override
  void initState() {
    super.initState();
    _client = TdlibClient();
    _themeManager = ThemeManager()..load();
    _notificationService = NotificationService()..init();

    _proxyManager = ProxyManager(client: _client, config: widget.config);

    _chatManager = ChatManager(
      client: _client,
      notificationService: _notificationService,
    );

    _authManager = AuthManager(
      client: _client,
      config: widget.config,
      proxyManager: _proxyManager,
      onAuthorized: () {
        _chatManager.startListening();
        _chatManager.loadChats();
      },
    );
  }

  @override
  void dispose() {
    _authManager.dispose();
    _chatManager.dispose();
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
