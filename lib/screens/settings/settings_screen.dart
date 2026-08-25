import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_manager.dart';
import '../../core/media/media_cache_manager.dart';
import '../../core/proxy/proxy_manager.dart';
import '../../core/theme/theme_manager.dart';
import '../../core/theme/theme_preferences.dart';
import '../../core/user/profile_manager.dart';
import '../../models/proxy_models.dart';
import '../../widgets/chat_avatar.dart';
import '../../widgets/proxy_status_indicator.dart';
import '../../widgets/storage_settings_section.dart';
import '../profile/own_profile_screen.dart';
import 'accounts_screen.dart';
import 'active_sessions_screen.dart';
import 'app_lock_settings_screen.dart';
import 'change_phone_screen.dart';
import 'blocked_users_screen.dart';
import 'notification_settings_screen.dart';
import '../../core/navigation/telegram_routes.dart';

/// Настройки: профиль, внешний вид, прокси, выход из аккаунта.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final proxyManager = context.watch<ProxyManager?>();
    final themeManager = context.watch<ThemeManager>();
    final mediaCache = context.watch<MediaCacheManager?>();
    final profile = context.watch<ProfileManager>();

    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ProfileHeader(profile: profile),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.block),
          title: const Text('Заблокированные пользователи'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            TelegramRoutes.push(context, const BlockedUsersScreen());
          },
        ),
        const Divider(height: 32),
        const SettingsNavigationSection(),
        const Divider(height: 32),
        Text('Внешний вид', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _ThemeModeSelector(themeManager: themeManager),
        const SizedBox(height: 16),
        Text('Акцентный цвет', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _AccentColorPicker(themeManager: themeManager),
        const SizedBox(height: 24),
        if (mediaCache != null) ...[
          StorageSettingsSection(),
          const SizedBox(height: 24),
        ],
        Text('Прокси', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (proxyManager == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Прокси не настроены.\nЗаполните PROXY_* в файле .env',
              ),
            ),
          )
        else
          _ProxySettings(proxyManager: proxyManager),
        const SizedBox(height: 24),
        Text('Аккаунт', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.switch_account_outlined),
          title: const Text('Аккаунты'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            TelegramRoutes.push(context, const AccountsScreen());
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.devices_other_outlined),
          title: const Text('Активные сессии'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            TelegramRoutes.push(context, const ActiveSessionsScreen());
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.phone_android_outlined),
          title: const Text('Смена номера'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            TelegramRoutes.push(context, const ChangePhoneScreen());
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_clock_outlined),
          title: const Text('Блокировка приложения'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            TelegramRoutes.push(context, const AppLockSettingsScreen());
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _confirmLogout(context),
          icon: const Icon(Icons.logout),
          label: const Text('Выйти из аккаунта'),
        ),
      ],
    );

    if (embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: body,
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти?'),
        content: const Text('Потребуется повторная авторизация.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
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
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final ProfileManager profile;

  @override
  Widget build(BuildContext context) {
    final user = profile.ownUser;
    final draft = profile.ownProfile;

    return Card(
      child: ListTile(
        leading: ChatAvatar(
          title: user?.displayName ?? 'Профиль',
          localPath: user?.avatarLocalPath,
          radius: 24,
        ),
        title: Text(user?.displayName ?? 'Мой профиль'),
        subtitle: Text(
          draft?.username.isNotEmpty == true
              ? '@${draft!.username}'
              : user?.username != null
                  ? '@${user!.username}'
                  : 'Имя, bio, username, фото',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          TelegramRoutes.push(context, const OwnProfileScreen());
        },
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.themeManager});

  final ThemeManager themeManager;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(value: ThemeMode.system, label: Text('Система')),
        ButtonSegment(value: ThemeMode.light, label: Text('Светлая')),
        ButtonSegment(value: ThemeMode.dark, label: Text('Тёмная')),
      ],
      selected: {themeManager.themeMode},
      onSelectionChanged: (selection) {
        themeManager.setThemeMode(selection.first);
      },
    );
  }
}

class _AccentColorPicker extends StatelessWidget {
  const _AccentColorPicker({required this.themeManager});

  final ThemeManager themeManager;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: ThemePreferences.accentOptions.map((color) {
        final selected =
            themeManager.accentColor.toARGB32() == color.toARGB32();
        return GestureDetector(
          onTap: () => themeManager.setAccentColor(color),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: color,
            child: selected ? const Icon(Icons.check, color: Colors.white) : null,
          ),
        );
      }).toList(),
    );
  }
}

class _ProxySettings extends StatelessWidget {
  const _ProxySettings({required this.proxyManager});

  final ProxyManager proxyManager;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Текущий статус', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                ProxyStatusIndicator(
                  status: proxyManager.status,
                  proxyName: proxyManager.activeProxyName,
                ),
                if (proxyManager.lastError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    proxyManager.lastError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Автоматическое переключение'),
          subtitle: const Text(
            'Failover PhantomProxy → StealthGate → системный',
          ),
          value: proxyManager.autoFailoverEnabled,
          onChanged: proxyManager.setAutoFailoverEnabled,
        ),
        ...proxyManager.proxies.map(
          (proxy) => _ProxyTile(
            proxy: proxy,
            onTest: () => _showTestResult(context, proxyManager, proxy.id),
            onActivate: () => proxyManager.activateProxy(proxy.id),
          ),
        ),
        if (proxyManager.userProxies.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Пользовательские прокси',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          ...proxyManager.userProxies.map(
            (proxy) => ListTile(
              dense: true,
              leading: Icon(
                proxy.type == UserProxyType.socks5
                    ? Icons.vpn_lock
                    : Icons.http,
              ),
              title: Text(proxy.name),
              subtitle: Text('${proxy.host}:${proxy.port}'),
            ),
          ),
        ],
        OutlinedButton.icon(
          onPressed: () => _showAddUserProxyDialog(context, proxyManager),
          icon: const Icon(Icons.add),
          label: const Text('Добавить SOCKS5 / HTTP'),
        ),
        FilledButton.icon(
          onPressed: proxyManager.switchToNextProxy,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Следующий прокси'),
        ),
      ],
    );
  }

  Future<void> _showAddUserProxyDialog(
    BuildContext context,
    ProxyManager manager,
  ) async {
    final nameController = TextEditingController();
    final hostController = TextEditingController(text: '127.0.0.1');
    final portController = TextEditingController(text: '1080');
    final userController = TextEditingController();
    final passController = TextEditingController();
    var type = UserProxyType.socks5;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Новый прокси'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                TextField(
                  controller: hostController,
                  decoration: const InputDecoration(labelText: 'Хост'),
                ),
                TextField(
                  controller: portController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Порт'),
                ),
                DropdownButtonFormField<UserProxyType>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Тип'),
                  items: const [
                    DropdownMenuItem(
                      value: UserProxyType.socks5,
                      child: Text('SOCKS5'),
                    ),
                    DropdownMenuItem(
                      value: UserProxyType.http,
                      child: Text('HTTP'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => type = value);
                    }
                  },
                ),
                TextField(
                  controller: userController,
                  decoration: const InputDecoration(
                    labelText: 'Логин (необязательно)',
                  ),
                ),
                TextField(
                  controller: passController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Пароль (необязательно)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && context.mounted) {
      final host = hostController.text.trim();
      final port = int.tryParse(portController.text.trim()) ?? 0;
      if (host.isEmpty || port <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Укажите корректный хост и порт')),
        );
      } else {
        await manager.addUserProxy(
          UserProxyConfig(
            id: '$host:$port:${type.name}',
            name: nameController.text.trim().isEmpty
                ? '$host:$port'
                : nameController.text.trim(),
            host: host,
            port: port,
            type: type,
            username: userController.text.trim(),
            password: passController.text,
          ),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Прокси добавлен')),
          );
        }
      }
    }

    nameController.dispose();
    hostController.dispose();
    portController.dispose();
    userController.dispose();
    passController.dispose();
  }

  Future<void> _showTestResult(
    BuildContext context,
    ProxyManager manager,
    int proxyId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final proxy = manager.proxies.firstWhere((item) => item.id == proxyId);

    messenger.showSnackBar(SnackBar(content: Text('Проверка ${proxy.name}...')));
    final ok = await manager.testProxy(proxyId);
    if (!context.mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? '${proxy.name}: доступен' : '${proxy.name}: недоступен'),
      ),
    );
  }
}

class _ProxyTile extends StatelessWidget {
  const _ProxyTile({
    required this.proxy,
    required this.onTest,
    required this.onActivate,
  });

  final ProxyEntry proxy;
  final VoidCallback onTest;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final healthLabel = switch (proxy.health) {
      ProxyHealth.ok => 'Доступен',
      ProxyHealth.failed => 'Недоступен',
      ProxyHealth.checking => 'Проверка...',
      ProxyHealth.unknown => 'Не проверен',
    };

    final healthColor = switch (proxy.health) {
      ProxyHealth.ok => Colors.green,
      ProxyHealth.failed => Colors.red,
      ProxyHealth.checking => Colors.amber,
      ProxyHealth.unknown => Colors.grey,
    };

    final isSystemTransport =
        proxy.name == ProxyManager.transportProxyName;

    return Card(
      child: ListTile(
        leading: Icon(
          proxy.isActive ? Icons.check_circle : Icons.radio_button_unchecked,
          color: proxy.isActive ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(proxy.name),
        subtitle: Text(
          isSystemTransport
              ? '$healthLabel • ${proxy.displayAddress} • транспорт + fallback'
              : '$healthLabel • ${proxy.displayAddress}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 10, color: healthColor),
            IconButton(
              tooltip: 'Тест',
              onPressed: onTest,
              icon: const Icon(Icons.network_check),
            ),
            if (!proxy.isActive)
              IconButton(
                tooltip: 'Включить',
                onPressed: onActivate,
                icon: const Icon(Icons.play_arrow),
              ),
          ],
        ),
      ),
    );
  }
}
