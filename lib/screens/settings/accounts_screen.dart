import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/account_manager.dart';
import '../../core/auth/auth_manager.dart';
import '../../models/account_models.dart';

/// Переключение и добавление аккаунтов.
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accountManager = context.watch<AccountManager>();

    return Scaffold(
      appBar: AppBar(title: const Text('Аккаунты')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Каждый аккаунт хранит отдельную базу TDLib на устройстве.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ...accountManager.accounts.map(
            (account) => _AccountTile(
              account: account,
              isActive: account.id == accountManager.activeAccountId,
              onTap: () => accountManager.switchAccount(account.id),
              onRemove: accountManager.accounts.length <= 1
                  ? null
                  : () => _confirmRemove(context, accountManager, account),
            ),
          ),
          const Divider(height: 32),
          Text('Прокси', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...AccountProxyPolicy.values.map(
            (policy) => RadioListTile<AccountProxyPolicy>(
              value: policy,
              groupValue: accountManager.proxyPolicy,
              onChanged: (value) {
                if (value != null) {
                  accountManager.setProxyPolicy(value);
                }
              },
              title: Text(policy.label),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _addAccount(context),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Добавить аккаунт'),
          ),
        ],
      ),
    );
  }

  Future<void> _addAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить аккаунт?'),
        content: const Text(
          'Текущий аккаунт будет отключён. После входа под другим номером '
          'можно переключаться между аккаунтами без смешивания чатов.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти и добавить'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthManager>().logOut();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    AccountManager manager,
    AccountSession account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить аккаунт с устройства?'),
        content: Text(
          'Локальные данные ${account.displayName.isNotEmpty ? account.displayName : account.phoneNumber} '
          'будут удалены при следующем переключении.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await manager.removeAccount(account.id);
    }
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isActive,
    required this.onTap,
    this.onRemove,
  });

  final AccountSession account;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final title = account.displayName.isNotEmpty
        ? account.displayName
        : account.phoneNumber.isNotEmpty
            ? account.phoneNumber
            : 'Аккаунт ${account.userId}';

    return Card(
      child: ListTile(
        leading: Icon(
          isActive ? Icons.check_circle : Icons.account_circle_outlined,
          color: isActive ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(title),
        subtitle: Text(
          account.phoneNumber.isNotEmpty
              ? account.phoneNumber
              : 'user_id: ${account.userId}',
        ),
        trailing: onRemove == null
            ? null
            : IconButton(
                tooltip: 'Удалить',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
        onTap: isActive ? null : onTap,
      ),
    );
  }
}
