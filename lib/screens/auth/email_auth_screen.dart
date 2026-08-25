import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_manager.dart';

/// Подтверждение e-mail при входе.
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key, this.isCodeStep = false});

  final bool isCodeStep;

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
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
      appBar: AppBar(
        title: Text(widget.isCodeStep ? 'Код из e-mail' : 'E-mail для входа'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isCodeStep
                    ? 'Введите код из письма'
                    : 'Telegram запросил e-mail',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                widget.isCodeStep
                    ? 'Код отправлен на ${auth.pendingEmailAddress ?? 'ваш e-mail'}.'
                    : 'Укажите адрес e-mail, привязанный к аккаунту.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _controller,
                keyboardType:
                    widget.isCodeStep ? TextInputType.number : TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: widget.isCodeStep ? 'Код' : 'E-mail',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Заполните поле';
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
                          if (widget.isCodeStep) {
                            auth.submitCode(_controller.text);
                          } else {
                            auth.submitEmailAddress(_controller.text);
                          }
                        }
                      },
                child: const Text('Продолжить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
