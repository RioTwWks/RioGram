import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/auth/auth_manager.dart';
import 'core/config/app_config.dart';
import 'core/proxy/proxy_manager.dart';
import 'core/tdlib/tdlib_client.dart';
import 'models/auth_models.dart';
import 'screens/auth/phone_screen.dart';
import 'screens/chats/chats_screen.dart';

class RioGramApp extends StatelessWidget {
  const RioGramApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return _AppScope(
      config: config,
      child: MaterialApp(
        title: 'RioGram',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2AABEE),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2AABEE),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const _RootScreen(),
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
  ProxyManager? _proxyManager;
  late final AuthManager _authManager;

  @override
  void initState() {
    super.initState();
    _client = TdlibClient();
    final hasProxies =
        widget.config.phantomProxy != null || widget.config.stealthProxy != null;
    if (hasProxies) {
      _proxyManager = ProxyManager(client: _client, config: widget.config);
    }
    _authManager = AuthManager(
      client: _client,
      config: widget.config,
      proxyManager: _proxyManager,
    );
  }

  @override
  void dispose() {
    _authManager.dispose();
    _proxyManager?.dispose();
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TdlibClient>.value(value: _client),
        ChangeNotifierProvider<AuthManager>.value(value: _authManager),
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
      AuthPhase.waitPhoneNumber ||
      AuthPhase.waitCode ||
      AuthPhase.waitPassword =>
        const PhoneScreen(),
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
