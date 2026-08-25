import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/plugins/builtin/signature_plugin.dart';
import '../../core/plugins/plugin_manager.dart';
import '../../models/plugin_models.dart';
import '../../widgets/telegram_settings_tile.dart';

/// Управление плагинами RioGram.
class PluginSettingsScreen extends StatelessWidget {
  const PluginSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<PluginManager>();
    final plugins = manager.descriptors;

    return Scaffold(
      appBar: AppBar(title: const Text('Плагины')),
      body: TelegramSettingsListView(
        children: [
          const TelegramSettingsSectionHeader('Установленные'),
          if (plugins.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Плагины не найдены'),
            )
          else
            TelegramSettingsGroup(
              children: [
                for (var i = 0; i < plugins.length; i++)
                  _PluginTile(
                    descriptor: plugins[i],
                    manager: manager,
                    showDivider: i < plugins.length - 1,
                  ),
              ],
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Плагины расширяют RioGram через хуки отображения и отправки '
              'сообщений. Документация для разработчиков: docs/PLUGINS.md',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _PluginTile extends StatelessWidget {
  const _PluginTile({
    required this.descriptor,
    required this.manager,
    required this.showDivider,
  });

  final PluginDescriptor descriptor;
  final PluginManager manager;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final manifest = descriptor.manifest;
    final state = descriptor.state;

    return Column(
      children: [
        TelegramSettingsTile(
          title: manifest.name,
          subtitle: '${manifest.description}\n'
              'v${manifest.version} · ${manifest.author}'
              '${descriptor.isBuiltin ? ' · встроенный' : ''}',
          trailing: Switch(
            value: state.enabled,
            onChanged: (value) => manager.setPluginEnabled(manifest.id, value),
          ),
          showChevron: manifest.id == SignaturePlugin.pluginId && state.enabled,
          onTap: manifest.id == SignaturePlugin.pluginId && state.enabled
              ? () => _openSignatureConfig(context)
              : null,
          showDivider: showDivider,
        ),
      ],
    );
  }

  Future<void> _openSignatureConfig(BuildContext context) async {
    final manager = context.read<PluginManager>();
    final current = manager.stateFor(SignaturePlugin.pluginId);
    final controller = TextEditingController(
      text: current.config['signature'] ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Подпись сообщений'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Подпись',
            hintText: '— RioGram',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (saved == true && context.mounted) {
      await manager.setPluginConfig(
        SignaturePlugin.pluginId,
        {'signature': controller.text.trim()},
      );
    }
    controller.dispose();
  }
}
