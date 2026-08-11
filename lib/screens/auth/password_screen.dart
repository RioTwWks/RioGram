import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_manager.dart';

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthManager>();

    return Scaffold(
      appBar: AppBar(title: const Text('Пароль 2FA')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Двухфакторная аутентификация',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Введите облачный пароль Telegram.'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _controller,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Пароль',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите пароль';
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
                          auth.submitPassword(_controller.text);
                        }
                      },
                child: auth.isAuthRequestInProgress
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Войти'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
