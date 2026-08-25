import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_manager.dart';

/// Регистрация нового аккаунта Telegram.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  var _acceptedTerms = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthManager>();
    final terms = auth.registrationTerms;

    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'Создание аккаунта',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (terms != null && terms.text.isNotEmpty) ...[
                Text('Условия использования', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(terms.text),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _acceptedTerms,
                  onChanged: (value) {
                    setState(() => _acceptedTerms = value ?? false);
                  },
                  title: const Text('Принимаю условия Telegram'),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Имя',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите имя';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Фамилия',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: auth.isAuthRequestInProgress ||
                        (terms != null &&
                            terms.text.isNotEmpty &&
                            !_acceptedTerms)
                    ? null
                    : () {
                        if (_formKey.currentState?.validate() ?? false) {
                          auth.registerUser(
                            firstName: _firstNameController.text,
                            lastName: _lastNameController.text,
                          );
                        }
                      },
                child: auth.isAuthRequestInProgress
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Зарегистрироваться'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
