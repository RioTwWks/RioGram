import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_manager.dart';
import '../../core/media/media_cache_manager.dart';
import '../../core/navigation/telegram_routes.dart';
import '../../core/proxy/proxy_manager.dart';
import '../../core/proxy/web_proxy_manager.dart';
import '../../core/theme/theme_manager.dart';
import '../../core/theme/theme_preferences.dart';
import '../../core/theme/telegram_theme.dart';
import '../../core/user/profile_manager.dart';
import '../../models/proxy_models.dart';
import '../../widgets/proxy_status_indicator.dart';
import '../../widgets/storage_settings_section.dart';
import '../../widgets/telegram_settings_tile.dart';
import '../../widgets/web_socket_proxy_settings.dart';
import '../profile/own_profile_screen.dart';
import 'accounts_screen.dart';
import 'ui_customization_settings_screen.dart';
import 'active_sessions_screen.dart';
import 'app_lock_settings_screen.dart';
import 'change_phone_screen.dart';
import 'blocked_users_screen.dart';
import 'notification_settings_screen.dart';

/// Настройки: профиль, внешний вид, прокси, выход из аккаунта.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final proxyManager = context.watch<ProxyManager?>();
    final webProxyManager = context.watch<WebProxyManager?>();
    final themeManager = context.watch<ThemeManager>();
    final mediaCache = context.watch<MediaCacheManager?>();
    final profile = context.watch<ProfileManager>();
    final auth = context.watch<AuthManager>();

    final user = profile.ownUser;
    final draft = profile.ownProfile;
    final displayName = user?.displayName ?? 'Мой профиль';
    final username = draft?.username.isNotEmpty == true
        ? draft!.username
        : user?.username;
    final phone = auth.phoneNumber?.isNotEmpty == true
        ? auth.phoneNumber
        : user?.phoneNumber;

    final body = TelegramSettingsListView(
      children: [
        TelegramSettingsProfileHeader(
          displayName: displayName,
          username: username,
          phone: phone,
          avatarLocalPath: user?.avatarLocalPath,
          onTap: () {
            TelegramRoutes.push(context, const OwnProfileScreen());
          },
        ),
        const TelegramSettingsSectionHeader('Конфиденциальность'),
        TelegramSettingsGroup(
          children: [
            TelegramSettingsTile(
              title: 'Заблокированные пользователи',
              onTap: () {
                TelegramRoutes.push(context, const BlockedUsersScreen());
              },
              showDivider: false,
            ),
          ],
        ),
        const SettingsNavigationSection(),
        const TelegramSettingsSectionHeader('Внешний вид'),
        TelegramSettingsGroup(
          children: [
            _ThemeModeTile(themeManager: themeManager),
            _AccentColorTile(themeManager: themeManager),
            TelegramSettingsTile(
              title: 'Кастомизация UI',
              subtitle: 'Шрифты, скругления, жесты, видимость',
              onTap: () {
                TelegramRoutes.push(
                  context,
                  const UiCustomizationSettingsScreen(),
                );
              },
              showDivider: false,
            ),
          ],
        ),
        if (mediaCache != null) const StorageSettingsSection(),
        const TelegramSettingsSectionHeader('Прокси'),
        if (kIsWeb && webProxyManager != null)
          WebSocketProxySettings(manager: webProxyManager)
        else if (proxyManager == null)
          TelegramSettingsGroup(
            children: const [
              TelegramSettingsTile(
                title: 'Прокси не настроены',
                subtitle: 'Заполните PROXY_* в файле .env',
                showChevron: false,
                showDivider: false,
              ),
            ],
          )
        else
          _ProxySettings(proxyManager: proxyManager),
        const TelegramSettingsSectionHeader('Аккаунт'),
        TelegramSettingsGroup(
          children: [
            TelegramSettingsTile(
              title: 'Аккаунты',
              onTap: () {
                TelegramRoutes.push(context, const AccountsScreen());
              },
            ),
            TelegramSettingsTile(
              title: 'Активные сессии',
              onTap: () {
                TelegramRoutes.push(context, const ActiveSessionsScreen());
              },
            ),
            TelegramSettingsTile(
              title: 'Смена номера',
              onTap: () {
                TelegramRoutes.push(context, const ChangePhoneScreen());
              },
            ),
            TelegramSettingsTile(
              title: 'Блокировка приложения',
              onTap: () {
                TelegramRoutes.push(context, const AppLockSettingsScreen());
              },
              showDivider: false,
            ),
          ],
        ),
        const SizedBox(height: 24),
        TelegramSettingsGroup(
          children: [
            TelegramSettingsTile(
              title: 'Выйти из аккаунта',
              showChevron: false,
              destructive: true,
              onTap: () => _confirmLogout(context),
              showDivider: false,
            ),
          ],
        ),
      ],
    );

    if (embedded) {
      return ColoredBox(
        color: telegramSettingsPageBackground(context),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: telegramSettingsPageBackground(context),
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

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({required this.themeManager});

  final ThemeManager themeManager;

  String _label(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Системная',
        ThemeMode.light => 'Светлая',
        ThemeMode.dark => 'Тёмная',
      };

  @override
  Widget build(BuildContext context) {
    return TelegramSettingsTile(
      title: 'Тема',
      value: _label(themeManager.themeMode),
      onTap: () async {
        await showModalBottomSheet<void>(
          context: context,
          backgroundColor: context.telegramTheme.elevatedSurface,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ThemeMode.values.map((mode) {
                return RadioListTile<ThemeMode>(
                  title: Text(_label(mode)),
                  value: mode,
                  groupValue: themeManager.themeMode,
                  onChanged: (value) {
                    if (value != null) {
                      themeManager.setThemeMode(value);
                      Navigator.pop(context);
                    }
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _AccentColorTile extends StatelessWidget {
  const _AccentColorTile({required this.themeManager});

  final ThemeManager themeManager;

  @override
  Widget build(BuildContext context) {
    return TelegramSettingsTile(
      title: 'Акцентный цвет',
      showChevron: false,
      showDivider: false,
      trailing: Wrap(
        spacing: 8,
        children: ThemePreferences.accentOptions.map((color) {
          final selected =
              themeManager.accentColor.toARGB32() == color.toARGB32();
          return GestureDetector(
            onTap: () => themeManager.setAccentColor(color),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(
                        color: context.telegramTheme.textPrimary,
                        width: 2,
                      )
                    : null,
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ProxySettings extends StatelessWidget {
  const _ProxySettings({required this.proxyManager});

  final ProxyManager proxyManager;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;

    return Column(
      children: [
        TelegramSettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Текущий статус',
                    style: TextStyle(
                      fontSize: TelegramFontSizes.chatSubtitle,
                      fontWeight: FontWeight.w600,
                      color: tg.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ProxyStatusIndicator(
                    status: proxyManager.status,
                    proxyName: proxyManager.activeProxyName,
                  ),
                  if (proxyManager.lastError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      proxyManager.lastError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const TelegramSettingsDivider(),
            TelegramSettingsSwitchTile(
              title: 'Автоматическое переключение',
              subtitle: 'Failover PhantomProxy → StealthGate → системный',
              value: proxyManager.autoFailoverEnabled,
              onChanged: proxyManager.setAutoFailoverEnabled,
              showDivider: proxyManager.proxies.isNotEmpty ||
                  proxyManager.userProxies.isNotEmpty,
            ),
            ...proxyManager.proxies.asMap().entries.map((entry) {
              final proxy = entry.value;
              final isLast = entry.key == proxyManager.proxies.length - 1 &&
                  proxyManager.userProxies.isEmpty;
              return _ProxyTile(
                proxy: proxy,
                showDivider: !isLast,
                onTest: () => _showTestResult(context, proxyManager, proxy.id),
                onActivate: () => proxyManager.activateProxy(proxy.id),
              );
            }),
            ...proxyManager.userProxies.asMap().entries.map((entry) {
              final proxy = entry.value;
              final isLast = entry.key == proxyManager.userProxies.length - 1;
              return TelegramSettingsTile(
                title: proxy.name,
                subtitle: '${proxy.host}:${proxy.port}',
                leading: Icon(
                  proxy.type == UserProxyType.socks5
                      ? Icons.vpn_lock_outlined
                      : Icons.http_outlined,
                  color: tg.textSecondary,
                ),
                showChevron: false,
                showDivider: !isLast,
              );
            }),
          ],
        ),
        const SizedBox(height: 12),
        TelegramSettingsGroup(
          children: [
            TelegramSettingsTile(
              title: 'Добавить SOCKS5 / HTTP',
              leading: Icon(Icons.add, color: tg.accent),
              showChevron: false,
              onTap: () => _showAddUserProxyDialog(context, proxyManager),
            ),
            TelegramSettingsTile(
              title: 'Следующий прокси',
              leading: Icon(Icons.swap_horiz, color: tg.accent),
              showChevron: false,
              showDivider: false,
              onTap: proxyManager.switchToNextProxy,
            ),
          ],
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
                    if (value != null) setState(() => type = value);
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
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? '${proxy.name}: доступен' : '${proxy.name}: недоступен',
        ),
      ),
    );
  }
}

class _ProxyTile extends StatelessWidget {
  const _ProxyTile({
    required this.proxy,
    required this.onTest,
    required this.onActivate,
    this.showDivider = true,
  });

  final ProxyEntry proxy;
  final VoidCallback onTest;
  final VoidCallback onActivate;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
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
      ProxyHealth.unknown => tg.textSecondary,
    };
    final isSystemTransport = proxy.name == ProxyManager.transportProxyName;
    final subtitle = isSystemTransport
        ? '$healthLabel • ${proxy.displayAddress} • транспорт + fallback'
        : '$healthLabel • ${proxy.displayAddress}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                proxy.isActive ? Icons.check_circle : Icons.radio_button_unchecked,
                color: proxy.isActive ? tg.accent : tg.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proxy.name,
                      style: TextStyle(
                        fontSize: TelegramFontSizes.chatTitle,
                        color: tg.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: TelegramFontSizes.chatSubtitle,
                        color: tg.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.circle, size: 8, color: healthColor),
              IconButton(
                tooltip: 'Тест',
                onPressed: onTest,
                icon: Icon(Icons.network_check, color: tg.accent),
              ),
              if (!proxy.isActive)
                IconButton(
                  tooltip: 'Включить',
                  onPressed: onActivate,
                  icon: Icon(Icons.play_arrow, color: tg.accent),
                ),
            ],
          ),
        ),
        if (showDivider) const TelegramSettingsDivider(inset: 56),
      ],
    );
  }
}
