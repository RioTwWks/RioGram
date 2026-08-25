import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/account_manager.dart';
import '../../core/auth/auth_manager.dart';
import '../../core/theme/telegram_theme.dart';
import '../../models/account_models.dart';
import '../../widgets/telegram_settings_tile.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accountManager = context.watch<AccountManager>();

    return TelegramSettingsScaffold(
      title: 'Аккаунты',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Каждый аккаунт хранит отдельную базу TDLib на устройстве.',
            style: TextStyle(fontSize: TelegramFontSizes.chatSubtitle, color: context.telegramTheme.textSecondary),
          ),
        ),
        TelegramSettingsGroup(
          children: [
            ...accountManager.accounts.asMap().entries.map((entry) {
              final account = entry.value;
              final isLast = entry.key == accountManager.accounts.length - 1;
              return _AccountTile(
                account: account,
                isActive: account.id == accountManager.activeAccountId,
                showDivider: !isLast,
                onTap: () => accountManager.switchAccount(account.id),
                onRemove: accountManager.accounts.length <= 1 ? null : () => _confirmRemove(context, accountManager, account),
              );
            }),
          ],
        ),
        const TelegramSettingsSectionHeader('Прокси'),
        TelegramSettingsGroup(
          children: [
            ...AccountProxyPolicy.values.asMap().entries.map((entry) {
              final policy = entry.value;
              final isLast = entry.key == AccountProxyPolicy.values.length - 1;
              return TelegramSettingsTile(
                title: policy.label,
                showChevron: false,
                showDivider: !isLast,
                trailing: Radio<AccountProxyPolicy>(
                  value: policy,
                  groupValue: accountManager.proxyPolicy,
                  onChanged: (value) {
                    if (value != null) accountManager.setProxyPolicy(value);
                  },
                ),
                onTap: () => accountManager.setProxyPolicy(policy),
              );
            }),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _addAccount(context),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Добавить аккаунт'),
        ),
      ],
    );
  }

  Future<void> _addAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить аккаунт?'),
        content: const Text('Текущий аккаунт будет отключён. После входа под другим номером можно переключаться между аккаунтами без смешивания чатов.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Выйти и добавить')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthManager>().logOut();
      if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _confirmRemove(BuildContext context, AccountManager manager, AccountSession account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить аккаунт с устройства?'),
        content: Text('Локальные данные ${account.displayName.isNotEmpty ? account.displayName : account.phoneNumber} будут удалены при следующем переключении.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed == true) await manager.removeAccount(account.id);
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account, required this.isActive, required this.onTap, this.onRemove, this.showDivider = true});

  final AccountSession account;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    final title = account.displayName.isNotEmpty
        ? account.displayName
        : account.phoneNumber.isNotEmpty
            ? account.phoneNumber
            : 'Аккаунт ${account.userId}';
    final subtitle = account.phoneNumber.isNotEmpty ? account.phoneNumber : 'user_id: ${account.userId}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isActive ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(isActive ? Icons.check_circle : Icons.account_circle_outlined, color: isActive ? tg.accent : tg.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontSize: TelegramFontSizes.chatTitle, color: tg.textPrimary)),
                        Text(subtitle, style: TextStyle(fontSize: TelegramFontSizes.chatSubtitle, color: tg.textSecondary)),
                      ],
                    ),
                  ),
                  if (onRemove != null)
                    IconButton(tooltip: 'Удалить', onPressed: onRemove, icon: Icon(Icons.delete_outline, color: tg.textSecondary)),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) const TelegramSettingsDivider(inset: 56),
      ],
    );
  }
}
