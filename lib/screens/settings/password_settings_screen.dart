import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/security/security_settings_manager.dart';
import '../../widgets/telegram_settings_tile.dart';

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

    return TelegramSettingsScaffold(
      title: 'Облачный пароль',
      children: [
        if (security.isLoading) const LinearProgressIndicator(),
        TelegramSettingsGroup(
          children: [
            TelegramSettingsTile(
              title: hasPassword ? '2FA включена' : '2FA не настроена',
              subtitle: hasPassword && state!.passwordHint.isNotEmpty
                  ? 'Подсказка: ${state.passwordHint}'
                  : hasPassword && state!.hasRecoveryEmail
                      ? 'Email: ${state.recoveryEmailPattern}'
                      : null,
              showChevron: false,
              showDivider: false,
            ),
          ],
        ),
        if (security.lastError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(security.lastError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: TelegramSettingsGroup(
            children: [
              if (hasPassword)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextFormField(
                    controller: _oldPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Текущий пароль'),
                    validator: (value) => value == null || value.isEmpty ? 'Введите текущий пароль' : null,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: hasPassword ? 'Новый пароль' : 'Пароль'),
                  validator: (value) => !hasPassword && (value == null || value.isEmpty) ? 'Введите пароль' : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(controller: _hintController, decoration: const InputDecoration(labelText: 'Подсказка')),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: TextField(controller: _recoveryController, decoration: const InputDecoration(labelText: 'Email восстановления (необязательно)')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: security.isSaving
              ? null
              : () {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  security.setPassword(
                    oldPassword: _oldPasswordController.text,
                    newPassword: _newPasswordController.text,
                    hint: _hintController.text,
                    recoveryEmail: _recoveryController.text.trim(),
                  );
                },
          child: security.isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(hasPassword ? 'Изменить пароль' : 'Установить пароль'),
        ),
        if (hasPassword) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: security.isSaving
                ? null
                : () {
                    if (_oldPasswordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите текущий пароль')));
                      return;
                    }
                    security.removePassword(oldPassword: _oldPasswordController.text);
                  },
            child: const Text('Отключить 2FA'),
          ),
        ],
      ],
    );
  }
}
