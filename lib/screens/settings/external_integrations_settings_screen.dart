import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/integrations/external_integrations_manager.dart';
import '../../widgets/telegram_settings_tile.dart';

/// Настройки внешних интеграций: автопостинг в канал или бота.
class ExternalIntegrationsSettingsScreen extends StatefulWidget {
  const ExternalIntegrationsSettingsScreen({super.key});

  @override
  State<ExternalIntegrationsSettingsScreen> createState() =>
      _ExternalIntegrationsSettingsScreenState();
}

class _ExternalIntegrationsSettingsScreenState
    extends State<ExternalIntegrationsSettingsScreen> {
  late final TextEditingController _chatIdController;
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    final manager = context.read<ExternalIntegrationsManager>();
    final target = manager.settings.autopostTarget;
    _chatIdController = TextEditingController(
      text: target.chatId == 0 ? '' : '${target.chatId}',
    );
    _titleController = TextEditingController(text: target.title);
  }

  @override
  void dispose() {
    _chatIdController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveTarget(ExternalIntegrationsManager manager) async {
    final chatId = int.tryParse(_chatIdController.text.trim()) ?? 0;
    final title = _titleController.text.trim();
    if (chatId == 0 || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите chat ID и название канала/бота')),
      );
      return;
    }
    await manager.setAutopostTarget(chatId: chatId, title: title);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Цель автопостинга сохранена')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ExternalIntegrationsManager>();
    final settings = manager.settings;
    final target = settings.autopostTarget;

    return Scaffold(
      appBar: AppBar(title: const Text('Интеграции')),
      body: TelegramSettingsListView(
        children: [
          const TelegramSettingsSectionHeader('Автопостинг'),
          TelegramSettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Название канала или бота',
                    hintText: 'Мой канал',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _chatIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Chat ID',
                    hintText: '-1001234567890',
                  ),
                ),
              ),
              TelegramSettingsTile(
                title: 'Сохранить цель',
                onTap: () => _saveTarget(manager),
              ),
              if (target.isConfigured)
                TelegramSettingsTile(
                  title: 'Очистить цель',
                  onTap: () async {
                    await manager.clearAutopostTarget();
                    _chatIdController.clear();
                    _titleController.clear();
                  },
                ),
              TelegramSettingsTile(
                title: 'Включить автопостинг',
                subtitle: target.isConfigured
                    ? target.title
                    : 'Сначала укажите канал или бота',
                trailing: Switch(
                  value: target.enabled,
                  onChanged: target.isConfigured
                      ? manager.setAutopostEnabled
                      : null,
                ),
                showChevron: false,
              ),
              TelegramSettingsTile(
                title: 'Дублировать исходящий текст',
                subtitle: 'Копировать отправленные сообщения в цель',
                trailing: Switch(
                  value: settings.mirrorOutgoingText,
                  onChanged: manager.setMirrorOutgoingText,
                ),
                showChevron: false,
                showDivider: false,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Автопостинг отправляет копию исходящих текстовых сообщений '
              'в выбранный канал или чат с ботом. Chat ID можно узнать в '
              'информации о чате или через @userinfobot.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
