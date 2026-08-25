import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/locale/app_locale_manager.dart';
import '../../core/navigation/telegram_routes.dart';
import '../../core/notifications/notification_settings_manager.dart';
import '../../widgets/notification_settings_section.dart';
import '../../widgets/telegram_settings_tile.dart';
import 'password_settings_screen.dart';
import 'privacy_settings_screen.dart';
import 'riogram_features_settings_screen.dart';
import 'security_privacy_settings_screen.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TelegramSettingsScaffold(
      title: 'Уведомления',
      children: const [NotificationSettingsSection()],
    );
  }
}

class LocaleSettingsScreen extends StatelessWidget {
  const LocaleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocaleManager>();
    return TelegramSettingsScaffold(
      title: 'Язык',
      children: [
        if (locale.lastError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              locale.lastError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TelegramSettingsGroup(
          children: [
            ...AppLocaleManager.supportedLocales.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isLast =
                  index == AppLocaleManager.supportedLocales.length - 1;
              return TelegramSettingsTile(
                title: option.label,
                showChevron: false,
                showDivider: !isLast,
                trailing: Radio<String>(
                  value: option.packId,
                  groupValue: locale.languagePackId,
                  onChanged: locale.isSaving
                      ? null
                      : (value) {
                          if (value != null) locale.setLanguagePack(value);
                        },
                ),
                onTap: locale.isSaving
                    ? null
                    : () => locale.setLanguagePack(option.packId),
              );
            }),
          ],
        ),
      ],
    );
  }
}

class SettingsNavigationSection extends StatelessWidget {
  const SettingsNavigationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TelegramSettingsSectionHeader('Уведомления и приватность'),
        TelegramSettingsGroup(
          children: [
            TelegramSettingsTile(
              title: 'Функции RioGram',
              subtitle: 'Призрачный режим, анти-отзыв, перевод',
              onTap: () {
                TelegramRoutes.push(
                  context,
                  const RioGramFeaturesSettingsScreen(),
                );
              },
            ),
            TelegramSettingsTile(
              title: 'Безопасность и приватность',
              subtitle: 'Local Premium, реклама, телеметрия',
              onTap: () {
                TelegramRoutes.push(
                  context,
                  const SecurityPrivacySettingsScreen(),
                );
              },
            ),
            TelegramSettingsTile(
              title: 'Уведомления',
              onTap: () {
                TelegramRoutes.push(context, const NotificationSettingsScreen());
              },
            ),
            TelegramSettingsTile(
              title: 'Приватность',
              onTap: () {
                TelegramRoutes.push(context, const PrivacySettingsScreen());
              },
            ),
            TelegramSettingsTile(
              title: 'Облачный пароль (2FA)',
              onTap: () {
                TelegramRoutes.push(context, const PasswordSettingsScreen());
              },
            ),
            TelegramSettingsTile(
              title: 'Язык',
              onTap: () {
                TelegramRoutes.push(context, const LocaleSettingsScreen());
              },
              showDivider: false,
            ),
          ],
        ),
        Consumer<NotificationSettingsManager>(
          builder: (context, manager, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TelegramSettingsSectionHeader('Система'),
              TelegramSettingsGroup(
                children: [
                  TelegramSettingsTile(
                    title: 'Непрочитанные (badge)',
                    value: '${manager.badgeCount}',
                    subtitle: 'без звука не учитываются',
                    showChevron: false,
                    showDivider: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
