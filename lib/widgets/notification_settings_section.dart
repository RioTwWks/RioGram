import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/notifications/notification_settings_manager.dart';
import '../../models/notification_settings_models.dart';

/// Глобальные настройки уведомлений по областям чатов.
class NotificationSettingsSection extends StatelessWidget {
  const NotificationSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<NotificationSettingsManager>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Уведомления', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (manager.lastError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              manager.lastError!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (manager.isLoadingScopes)
          const LinearProgressIndicator(),
        ...NotificationScopeKind.values.map((scope) {
          final settings =
              manager.scopeSettings[scope] ?? const ScopeNotificationSettingsModel();
          return Card(
            child: Column(
              children: [
                ListTile(
                  title: Text(scope.label),
                  subtitle: Text(
                    settings.isMuted ? 'Без звука' : 'Включены',
                  ),
                ),
                SwitchListTile(
                  title: const Text('Без звука'),
                  value: settings.isMuted,
                  onChanged: manager.isSaving
                      ? null
                      : (value) => manager.setScopeMuted(scope, muted: value),
                ),
                SwitchListTile(
                  title: const Text('Показывать текст'),
                  value: settings.showPreview,
                  onChanged: manager.isSaving
                      ? null
                      : (value) =>
                          manager.setScopeShowPreview(scope, showPreview: value),
                ),
              ],
            ),
          );
        }),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.timer_outlined),
          title: const Text('Автоудаление по умолчанию'),
          subtitle: Text(manager.defaultAutoDelete.label),
          trailing: DropdownButton<AutoDeletePreset>(
            value: manager.defaultAutoDelete,
            onChanged: manager.isSaving
                ? null
                : (value) {
                    if (value != null) {
                      manager.setDefaultAutoDelete(value);
                    }
                  },
            items: AutoDeletePreset.values
                .map(
                  (preset) => DropdownMenuItem(
                    value: preset,
                    child: Text(preset.label),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
