import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/proxy/proxy_manager.dart';
import '../../widgets/proxy_status_indicator.dart';

/// Экран настроек прокси и failover.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final proxyManager = context.watch<ProxyManager?>();

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: proxyManager == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Прокси не настроены.\nЗаполните PROXY_* переменные в файле .env',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Текущий статус',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
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
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Автоматическое переключение'),
                  subtitle: const Text(
                    'При недоступности PhantomProxy переключиться на StealthGate',
                  ),
                  value: proxyManager.autoFailoverEnabled,
                  onChanged: (value) {
                    proxyManager.setAutoFailoverEnabled(value);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Прокси-серверы',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...proxyManager.proxies.map(
                  (proxy) => _ProxyTile(
                    proxy: proxy,
                    onTest: () => _showTestResult(context, proxyManager, proxy.id),
                    onActivate: () => proxyManager.activateProxy(proxy.id),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => proxyManager.switchToNextProxy(),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Переключить на следующий прокси'),
                ),
              ],
            ),
    );
  }

  Future<void> _showTestResult(
    BuildContext context,
    ProxyManager manager,
    int proxyId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final proxy = manager.proxies.firstWhere((item) => item.id == proxyId);

    messenger.showSnackBar(
      SnackBar(content: Text('Проверка ${proxy.name}...')),
    );

    final ok = await manager.testProxy(proxyId);
    if (!context.mounted) {
      return;
    }

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
            const SizedBox(width: 8),
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
