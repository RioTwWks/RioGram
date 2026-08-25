import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/telegram_theme.dart';

/// Минимальная оболочка RioGram для PoC §8.1.
///
/// Не подключается к TDLib/Telegram — только проверка, что Flutter Web
/// рендерит UI в стиле Telegram. Сборка:
/// `flutter build web -t lib/main_web_poc.dart --release`
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  runApp(const RioGramWebPocApp());
}

class RioGramWebPocApp extends StatelessWidget {
  const RioGramWebPocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RioGram Web PoC',
      debugShowCheckedModeBanner: false,
      theme: TelegramTheme.build(brightness: Brightness.light),
      darkTheme: TelegramTheme.build(brightness: Brightness.dark),
      home: const _WebPocHomeScreen(),
    );
  }
}

class _WebPocHomeScreen extends StatefulWidget {
  const _WebPocHomeScreen();

  @override
  State<_WebPocHomeScreen> createState() => _WebPocHomeScreenState();
}

class _WebPocHomeScreenState extends State<_WebPocHomeScreen> {
  final _phoneController = TextEditingController(text: '+7');

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.telegramTheme;

    return Scaffold(
      backgroundColor: colors.chatListBackground,
      appBar: AppBar(
        title: const Text('RioGram'),
        backgroundColor: colors.chatListBackground,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.telegram, size: 72, color: colors.accent),
                const SizedBox(height: 16),
                Text(
                  'Web PoC §8.1',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'UI без подключения к Telegram. Основное приложение '
                  '(`lib/main.dart`) пока не собирается для Web из‑за TDLib FFI.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Номер телефона',
                    filled: true,
                    fillColor: colors.inputFieldBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'PoC: кнопка «Далее» работает, TDLib не подключён',
                        ),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Далее'),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.elevatedSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Транспорт: WSS через RU Frontend → EU Backend\n'
                    'См. docs/WEB_POC.md',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
