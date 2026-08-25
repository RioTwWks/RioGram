import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/security/app_lock_manager.dart';
import '../../widgets/telegram_settings_tile.dart';

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  final _passcodeController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passcodeController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockManager>();

    return TelegramSettingsScaffold(
      title: 'Блокировка приложения',
      children: [
        TelegramSettingsGroup(
          children: [
            TelegramSettingsSwitchTile(
              title: 'PIN-код',
              subtitle: lock.passcodeEnabled ? 'Включён' : 'Выключен',
              value: lock.passcodeEnabled,
              onChanged: (enabled) async {
                if (enabled) {
                  await _showSetPasscodeDialog(context, lock);
                } else {
                  await _showRemovePasscodeDialog(context, lock);
                }
              },
            ),
            TelegramSettingsSwitchTile(
              title: 'Биометрия',
              subtitle: 'Face ID / Touch ID / отпечаток',
              value: lock.biometricsEnabled,
              onChanged: !lock.passcodeEnabled ? null : lock.setBiometricsEnabled,
              showDivider: false,
            ),
          ],
        ),
        const TelegramSettingsSectionHeader('Автоблокировка'),
        TelegramSettingsGroup(
          children: [
            ...const [0, 1, 5, 15, 60].asMap().entries.map((entry) {
              final minutes = entry.value;
              final isLast = entry.key == 4;
              return TelegramSettingsTile(
                title: _autoLockLabel(minutes),
                showChevron: false,
                showDivider: !isLast,
                trailing: Radio<int>(
                  value: minutes,
                  groupValue: lock.autoLockMinutes,
                  onChanged: !lock.passcodeEnabled
                      ? null
                      : (value) {
                          if (value != null) lock.setAutoLockMinutes(value);
                        },
                ),
                onTap: !lock.passcodeEnabled ? null : () => lock.setAutoLockMinutes(minutes),
              );
            }),
          ],
        ),
        const SizedBox(height: 16),
        TelegramSettingsGroup(
          children: [
            TelegramSettingsTile(
              title: 'Заблокировать сейчас',
              showChevron: false,
              showDivider: false,
              onTap: !lock.passcodeEnabled ? null : lock.lockNow,
            ),
          ],
        ),
      ],
    );
  }

  String _autoLockLabel(int minutes) => switch (minutes) {
        0 => 'Выкл.',
        1 => '1 минута',
        5 => '5 минут',
        15 => '15 минут',
        60 => '1 час',
        _ => '$minutes мин.',
      };

  Future<void> _showSetPasscodeDialog(BuildContext context, AppLockManager lock) async {
    _passcodeController.clear();
    _confirmController.clear();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _passcodeController, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN (мин. 4 цифры)')),
            TextField(controller: _confirmController, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Повтор PIN')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Сохранить')),
        ],
      ),
    );
    if (saved != true || !context.mounted) return;
    if (_passcodeController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN не совпадает')));
      return;
    }
    final ok = await lock.setPasscode(_passcodeController.text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'PIN установлен' : 'PIN слишком короткий')));
    }
  }

  Future<void> _showRemovePasscodeDialog(BuildContext context, AppLockManager lock) async {
    final controller = TextEditingController();
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отключить PIN?'),
        content: TextField(controller: controller, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Текущий PIN')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              final passcode = controller.text;
              Navigator.pop(context, true);
              await lock.removePasscode(passcode);
            },
            child: const Text('Отключить'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}
