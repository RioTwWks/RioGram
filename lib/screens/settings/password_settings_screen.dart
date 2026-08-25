import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/security/security_settings_manager.dart';

/// Управление облачным паролем (2FA) в настройках.
class PasswordSettingsScreen extends StatefulWidget {
  const PasswordSettingsScreen({super.key});

  @override
  State<PasswordSettingsScreen> createState() => _PasswordSettingsScreenState();
}

class _PasswordSettingsScreenState extends State<PasswordSettingsScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _hintController = TextEditingController();
  final _recoveryController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _hintController.dispose();
    _recoveryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final security = context.watch<SecuritySettingsManager>();
    final state = security.passwordState;
    final hasPassword = state?.hasPassword ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Облачный пароль')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (security.isLoading)
            const LinearProgressIndicator()
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPassword ? '2FA включена' : '2FA не настроена',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (hasPassword && state!.passwordHint.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Подсказка: ${state.passwordHint}'),
                    ],
                    if (hasPassword && state!.hasRecoveryEmail) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Email восстановления: ${state.recoveryEmailPattern}',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (security.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              security.lastError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                if (hasPassword)
                  TextFormField(
                    controller: _oldPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Текущий пароль',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите текущий пароль';
                      }
                      return null;
                    },
                  ),
                if (hasPassword) const SizedBox(height: 12),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: hasPassword ? 'Новый пароль' : 'Пароль',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (!hasPassword && (value == null || value.isEmpty)) {
                      return 'Введите пароль';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hintController,
                  decoration: const InputDecoration(
                    labelText: 'Подсказка',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _recoveryController,
                  decoration: const InputDecoration(
                    labelText: 'Email восстановления (необязательно)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: security.isSaving
                      ? null
                      : () {
                          if (!(_formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          security.setPassword(
                            oldPassword: _oldPasswordController.text,
                            newPassword: _newPasswordController.text,
                            hint: _hintController.text,
                            recoveryEmail: _recoveryController.text.trim(),
                          );
                        },
                  child: security.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(hasPassword ? 'Изменить пароль' : 'Установить пароль'),
                ),
                if (hasPassword) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: security.isSaving
                        ? null
                        : () {
                            if (_oldPasswordController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Введите текущий пароль'),
                                ),
                              );
                              return;
                            }
                            security.removePassword(
                              oldPassword: _oldPasswordController.text,
                            );
                          },
                    child: const Text('Отключить 2FA'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
