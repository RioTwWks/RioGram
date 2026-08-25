import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/phone_change_manager.dart';
import '../../widgets/telegram_settings_tile.dart';

class ChangePhoneScreen extends StatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  final _phoneController = TextEditingController(text: '+7');
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  var _codeSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<PhoneChangeManager>();
    if (manager.pendingPhoneNumber != null && !_codeSent) _codeSent = true;
    if (manager.pendingPhoneNumber == null) _codeSent = false;

    return TelegramSettingsScaffold(
      title: 'Смена номера',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            _codeSent ? 'Подтверждение нового номера' : 'Новый номер телефона',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Form(
          key: _formKey,
          child: TelegramSettingsGroup(
            children: [
              if (!_codeSent)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Номер'),
                    validator: (value) => value == null || value.trim().length < 8 ? 'Введите корректный номер' : null,
                  ),
                )
              else ...[
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text(manager.codeInfoMessage ?? 'Код отправлен')),
                Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text('Номер: ${manager.pendingPhoneNumber}')),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: TextFormField(controller: _codeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Код')),
                ),
              ],
            ],
          ),
        ),
        if (manager.lastError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(manager.lastError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: manager.isSendingCode || manager.isCheckingCode
              ? null
              : () {
                  if (!_codeSent) {
                    if (_formKey.currentState?.validate() ?? false) {
                      manager.requestChangeCode(_phoneController.text);
                    }
                  } else {
                    manager.submitChangeCode(_codeController.text);
                  }
                },
          child: Text(_codeSent ? 'Подтвердить' : 'Отправить код'),
        ),
      ],
    );
  }
}
