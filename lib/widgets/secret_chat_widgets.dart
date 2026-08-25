import 'package:flutter/material.dart';

import '../models/secret_chat_models.dart';

/// Индикатор E2E-ключа секретного чата (emoji grid).
class SecretChatKeyIndicator extends StatelessWidget {
  const SecretChatKeyIndicator({
    super.key,
    required this.secretChat,
  });

  final SecretChatSummary secretChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stateLabel = switch (secretChat.state) {
      SecretChatStateKind.pending => 'Обмен ключами…',
      SecretChatStateKind.ready => 'Шифрование активно',
      SecretChatStateKind.closed => 'Чат закрыт',
      SecretChatStateKind.unknown => 'Секретный чат',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Секретный чат', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(stateLabel),
            if (secretChat.keyHash.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Ключ шифрования',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              SelectableText(
                secretChat.keyHash,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Сверьте emoji-ключ с собеседником',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Выбор таймера самоуничтожения для секретного чата.
class SecretChatTtlPicker extends StatelessWidget {
  const SecretChatTtlPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final SecretChatTtlPreset value;
  final ValueChanged<SecretChatTtlPreset> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.timer_outlined),
      title: const Text('Таймер самоуничтожения'),
      subtitle: const Text('Сообщения удаляются после прочтения'),
      trailing: DropdownButton<SecretChatTtlPreset>(
        value: value,
        onChanged: (preset) {
          if (preset != null) {
            onChanged(preset);
          }
        },
        items: SecretChatTtlPreset.values
            .map(
              (preset) => DropdownMenuItem(
                value: preset,
                child: Text(preset.label),
              ),
            )
            .toList(),
      ),
    );
  }
}
