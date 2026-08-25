import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/security/app_lock_manager.dart';

/// Настройка PIN-кода, биометрии и автоблокировки.
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

    return Scaffold(
      appBar: AppBar(title: const Text('Блокировка приложения')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('PIN-код'),
            subtitle: Text(
              lock.passcodeEnabled ? 'Включён' : 'Выключен',
            ),
            value: lock.passcodeEnabled,
            onChanged: (enabled) async {
              if (enabled) {
                await _showSetPasscodeDialog(context, lock);
              } else {
                await _showRemovePasscodeDialog(context, lock);
              }
            },
          ),
          SwitchListTile(
            title: const Text('Биометрия'),
            subtitle: const Text('Face ID / Touch ID / отпечаток'),
            value: lock.biometricsEnabled,
            onChanged: !lock.passcodeEnabled
                ? null
                : (value) => lock.setBiometricsEnabled(value),
          ),
          const Divider(height: 32),
          Text('Автоблокировка', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...const [0, 1, 5, 15, 60].map(
            (minutes) => RadioListTile<int>(
              value: minutes,
              groupValue: lock.autoLockMinutes,
              onChanged: !lock.passcodeEnabled
                  ? null
                  : (value) {
                      if (value != null) {
                        lock.setAutoLockMinutes(value);
                      }
                    },
              title: Text(_autoLockLabel(minutes)),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: !lock.passcodeEnabled ? null : lock.lockNow,
            icon: const Icon(Icons.lock_outline),
            label: const Text('Заблокировать сейчас'),
          ),
        ],
      ),
    );
  }

  String _autoLockLabel(int minutes) {
    return switch (minutes) {
      0 => 'Выкл.',
      1 => '1 минута',
      5 => '5 минут',
      15 => '15 минут',
      60 => '1 час',
      _ => '$minutes мин.',
    };
  }

  Future<void> _showSetPasscodeDialog(
    BuildContext context,
    AppLockManager lock,
  ) async {
    _passcodeController.clear();
    _confirmController.clear();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _passcodeController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'PIN (мин. 4 цифры)'),
            ),
            TextField(
              controller: _confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Повтор PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (saved != true || !context.mounted) {
      return;
    }
    if (_passcodeController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN не совпадает')),
      );
      return;
    }
    final ok = await lock.setPasscode(_passcodeController.text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'PIN установлен' : 'PIN слишком короткий'),
        ),
      );
    }
  }

  Future<void> _showRemovePasscodeDialog(
    BuildContext context,
    AppLockManager lock,
  ) async {
    final controller = TextEditingController();
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отключить PIN?'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Текущий PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
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
