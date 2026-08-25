import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/privacy/privacy_settings_manager.dart';
import '../../core/theme/telegram_theme.dart';
import '../../models/privacy_settings_models.dart';
import '../../widgets/telegram_settings_tile.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<PrivacySettingsManager>();

    return TelegramSettingsScaffold(
      title: 'Приватность',
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
        const TelegramSettingsSectionHeader('Кто видит'),
        TelegramSettingsGroup(
          children: [
            _PrivacyTile(manager: manager, setting: PrivacySettingKind.showPhoneNumber),
            _PrivacyTile(manager: manager, setting: PrivacySettingKind.showProfilePhoto),
            _PrivacyTile(manager: manager, setting: PrivacySettingKind.showStatus, showDivider: false),
          ],
        ),
        const TelegramSettingsSectionHeader('Кто может'),
        TelegramSettingsGroup(
          children: [
            _PrivacyTile(manager: manager, setting: PrivacySettingKind.allowChatInvites),
            _PrivacyTile(manager: manager, setting: PrivacySettingKind.allowCalls),
            _PrivacyTile(manager: manager, setting: PrivacySettingKind.allowFindingByPhoneNumber, showDivider: false),
          ],
        ),
      ],
    );
  }
}

class _PrivacyTile extends StatelessWidget {
  const _PrivacyTile({required this.manager, required this.setting, this.showDivider = true});

  final PrivacySettingsManager manager;
  final PrivacySettingKind setting;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final preset = manager.presetFor(setting);
    return TelegramSettingsTile(
      title: setting.label,
      value: preset.label,
      showChevron: false,
      showDivider: showDivider,
      onTap: manager.isSaving ? null : () => _showPresetPicker(context, preset),
    );
  }

  Future<void> _showPresetPicker(BuildContext context, PrivacyRulePreset current) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.telegramTheme.elevatedSurface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: PrivacyRulePreset.values.map((preset) {
            return RadioListTile<PrivacyRulePreset>(
              title: Text(preset.label),
              value: preset,
              groupValue: current,
              onChanged: manager.isSaving
                  ? null
                  : (value) {
                      if (value != null) {
                        manager.setPreset(setting, value);
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
