import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_manager.dart';
import '../../models/auth_models.dart';
import 'code_screen.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _controller = TextEditingController(text: '+7');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthManager>();

    if (auth.phase == AuthPhase.waitCode) {
      return const CodeScreen();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Вход в RioGram')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Введите номер телефона',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Мы отправим код подтверждения в Telegram.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Номер телефона',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 8) {
                    return 'Введите корректный номер';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: auth.isAuthRequestInProgress
                    ? null
                    : () {
                        if (_formKey.currentState?.validate() ?? false) {
                          auth.submitPhoneNumber(_controller.text);
                        }
                      },
                child: auth.isAuthRequestInProgress
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Продолжить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
