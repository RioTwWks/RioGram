import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/phone_change_manager.dart';

/// Смена номера телефона аккаунта.
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

    if (manager.pendingPhoneNumber != null && !_codeSent) {
      _codeSent = true;
    }
    if (manager.pendingPhoneNumber == null) {
      _codeSent = false;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Смена номера')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _codeSent ? 'Подтверждение нового номера' : 'Новый номер телефона',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (!_codeSent) ...[
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Номер',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 8) {
                      return 'Введите корректный номер';
                    }
                    return null;
                  },
                ),
              ] else ...[
                Text(manager.codeInfoMessage ?? 'Код отправлен'),
                const SizedBox(height: 12),
                Text('Номер: ${manager.pendingPhoneNumber}'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Код',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (manager.lastError != null) ...[
                const SizedBox(height: 12),
                Text(
                  manager.lastError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const Spacer(),
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
          ),
        ),
      ),
    );
  }
}
