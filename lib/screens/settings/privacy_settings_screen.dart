import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/privacy/privacy_settings_manager.dart';
import '../../models/privacy_settings_models.dart';

/// Экран настроек приватности аккаунта.
class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<PrivacySettingsManager>();

    return Scaffold(
      appBar: AppBar(title: const Text('Приватность')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (manager.lastError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                manager.lastError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (manager.isLoading) const LinearProgressIndicator(),
          Text(
            'Кто видит',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...[
            PrivacySettingKind.showPhoneNumber,
            PrivacySettingKind.showProfilePhoto,
            PrivacySettingKind.showStatus,
          ].map(
            (setting) => _PrivacyTile(manager: manager, setting: setting),
          ),
          const SizedBox(height: 16),
          Text(
            'Кто может',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...[
            PrivacySettingKind.allowChatInvites,
            PrivacySettingKind.allowCalls,
            PrivacySettingKind.allowFindingByPhoneNumber,
          ].map(
            (setting) => _PrivacyTile(manager: manager, setting: setting),
          ),
        ],
      ),
    );
  }
}

class _PrivacyTile extends StatelessWidget {
  const _PrivacyTile({
    required this.manager,
    required this.setting,
  });

  final PrivacySettingsManager manager;
  final PrivacySettingKind setting;

  @override
  Widget build(BuildContext context) {
    final preset = manager.presetFor(setting);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(setting.label),
      trailing: DropdownButton<PrivacyRulePreset>(
        value: preset,
        onChanged: manager.isSaving
            ? null
            : (value) {
                if (value != null) {
                  manager.setPreset(setting, value);
                }
              },
        items: PrivacyRulePreset.values
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(item.label),
              ),
            )
            .toList(),
      ),
    );
  }
}
