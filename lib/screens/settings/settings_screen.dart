import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_manager.dart';
import '../../core/media/media_cache_manager.dart';
import '../../core/proxy/proxy_manager.dart';
import '../../core/theme/theme_manager.dart';
import '../../core/theme/theme_preferences.dart';
import '../../widgets/proxy_status_indicator.dart';
import '../../widgets/storage_settings_section.dart';

/// Настройки: внешний вид, прокси, выход из аккаунта.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final proxyManager = context.watch<ProxyManager?>();
    final themeManager = context.watch<ThemeManager>();
    final mediaCache = context.watch<MediaCacheManager?>();

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout),
            label: const Text('Выйти из аккаунта'),
          ),
        ],
      ),
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
        final selected = themeManager.accentColor.toARGB32() == color.toARGB32();
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
          subtitle: const Text('Failover PhantomProxy → StealthGate'),
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
        FilledButton.icon(
          onPressed: proxyManager.switchToNextProxy,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Следующий прокси'),
        ),
      ],
    );
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

    return Card(
      child: ListTile(
        leading: Icon(
          proxy.isActive ? Icons.check_circle : Icons.radio_button_unchecked,
          color: proxy.isActive ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(proxy.name),
        subtitle: Text('$healthLabel • ${proxy.displayAddress}'),
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
