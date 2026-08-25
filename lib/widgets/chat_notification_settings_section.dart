import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/notifications/notification_settings_manager.dart';
import '../../models/chat_models.dart';
import '../../models/notification_settings_models.dart';
import '../core/notifications/tdlib_notification_parser.dart';

/// Настройки уведомлений и автоудаления для конкретного чата.
class ChatNotificationSettingsSection extends StatefulWidget {
  const ChatNotificationSettingsSection({
    super.key,
    required this.chatId,
    required this.chatKind,
  });

  final int chatId;
  final ChatKind chatKind;

  @override
  State<ChatNotificationSettingsSection> createState() =>
      _ChatNotificationSettingsSectionState();
}

class _ChatNotificationSettingsSectionState
    extends State<ChatNotificationSettingsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationSettingsManager>().loadChatSettings(widget.chatId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<NotificationSettingsManager>();
    final scope = TdlibNotificationParser.scopeForChatKind(widget.chatKind);
    final scopeSettings =
        manager.scopeSettings[scope] ?? const ScopeNotificationSettingsModel();
    final chatSettings =
        manager.chatSettingsFor(widget.chatId) ?? const ChatNotificationSettingsModel();
    final isMuted = chatSettings.isMuted(scope: scopeSettings);
    final showPreview =
        chatSettings.effectiveShowPreview(scope: scopeSettings);
    final autoDelete = AutoDeletePresetX.fromSeconds(
      manager.autoDeleteSecondsFor(widget.chatId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Уведомления', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Без звука'),
          value: isMuted,
          onChanged: manager.isSaving
              ? null
              : (value) {
                  if (value) {
                    manager.muteChat(widget.chatId);
                  } else {
                    manager.unmuteChat(widget.chatId);
                  }
                },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Показывать текст'),
          value: showPreview,
          onChanged: manager.isSaving
              ? null
              : (value) => manager.setChatShowPreview(
                    widget.chatId,
                    showPreview: value,
                  ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.auto_delete_outlined),
          title: const Text('Автоудаление сообщений'),
          subtitle: Text(autoDelete.label),
          trailing: DropdownButton<AutoDeletePreset>(
            value: autoDelete,
            onChanged: manager.isSaving
                ? null
                : (value) {
                    if (value != null) {
                      manager.setChatAutoDelete(widget.chatId, value);
                    }
                  },
            items: AutoDeletePreset.values
                .map(
                  (preset) => DropdownMenuItem(
                    value: preset,
                    child: Text(preset.label),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
