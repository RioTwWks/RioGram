import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/locale/app_locale_manager.dart';
import '../../core/notifications/notification_settings_manager.dart';
import '../../widgets/notification_settings_section.dart';
import 'password_settings_screen.dart';
import 'privacy_settings_screen.dart';

/// Экран глобальных настроек уведомлений.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          NotificationSettingsSection(),
        ],
      ),
    );
  }
}

/// Экран языка интерфейса TDLib.
class LocaleSettingsScreen extends StatelessWidget {
  const LocaleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocaleManager>();

    return Scaffold(
      appBar: AppBar(title: const Text('Язык')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (locale.lastError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                locale.lastError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ...AppLocaleManager.supportedLocales.map(
            (option) => RadioListTile<String>(
              title: Text(option.label),
              value: option.packId,
              groupValue: locale.languagePackId,
              onChanged: locale.isSaving
                  ? null
                  : (value) {
                      if (value != null) {
                        locale.setLanguagePack(value);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}

/// Ссылки на подразделы §6.9 в главных настройках.
class SettingsNavigationSection extends StatelessWidget {
  const SettingsNavigationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Уведомления и приватность', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Уведомления'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            );
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_outline),
          title: const Text('Приватность'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PrivacySettingsScreen(),
              ),
            );
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.password_outlined),
          title: const Text('Облачный пароль (2FA)'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PasswordSettingsScreen(),
              ),
            );
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.language),
          title: const Text('Язык'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LocaleSettingsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Consumer<NotificationSettingsManager>(
          builder: (context, manager, _) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.mark_chat_unread_outlined),
              title: const Text('Непрочитанные (badge)'),
              subtitle: Text('${manager.badgeCount} без звука не учитываются'),
            );
          },
        ),
      ],
    );
  }
}
