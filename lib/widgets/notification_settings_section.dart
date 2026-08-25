import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/notifications/notification_settings_manager.dart';
import '../core/theme/telegram_theme.dart';
import '../models/notification_settings_models.dart';
import 'telegram_settings_tile.dart';

class NotificationSettingsSection extends StatelessWidget {
  const NotificationSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<NotificationSettingsManager>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (manager.lastError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(manager.lastError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (manager.isLoadingScopes) const LinearProgressIndicator(),
        ...NotificationScopeKind.values.map((scope) {
          final settings = manager.scopeSettings[scope] ?? const ScopeNotificationSettingsModel();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TelegramSettingsSectionHeader(scope.label),
              TelegramSettingsGroup(
                children: [
                  TelegramSettingsSwitchTile(
                    title: 'Без звука',
                    value: settings.isMuted,
                    onChanged: manager.isSaving ? null : (value) => manager.setScopeMuted(scope, muted: value),
                  ),
                  TelegramSettingsSwitchTile(
                    title: 'Показывать текст',
                    value: settings.showPreview,
                    onChanged: manager.isSaving ? null : (value) => manager.setScopeShowPreview(scope, showPreview: value),
                    showDivider: false,
                  ),
                ],
              ),
            ],
          );
        }),
        const TelegramSettingsSectionHeader('Дополнительно'),
        TelegramSettingsGroup(
          children: [
            TelegramSettingsTile(
              title: 'Автоудаление по умолчанию',
              value: manager.defaultAutoDelete.label,
              showChevron: false,
              showDivider: false,
              onTap: manager.isSaving ? null : () => _showAutoDeletePicker(context, manager),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showAutoDeletePicker(BuildContext context, NotificationSettingsManager manager) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.telegramTheme.elevatedSurface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AutoDeletePreset.values.map((preset) {
            return RadioListTile<AutoDeletePreset>(
              title: Text(preset.label),
              value: preset,
              groupValue: manager.defaultAutoDelete,
              onChanged: manager.isSaving
                  ? null
                  : (value) {
                      if (value != null) {
                        manager.setDefaultAutoDelete(value);
                        Navigator.pop(context);
                      }
                    },
            );
          }).toList(),
        ),
      ),
    );
  }
}
