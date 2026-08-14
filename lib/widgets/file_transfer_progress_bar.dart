import 'package:flutter/material.dart';

import '../models/audio_models.dart';

/// Индикатор загрузки/отправки файла с кнопкой отмены.
class FileTransferProgressBar extends StatelessWidget {
  const FileTransferProgressBar({
    super.key,
    required this.transfer,
    this.onCancel,
  });

  final FileTransferState transfer;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${transfer.label} ${transfer.progressPercent}%',
                  style: theme.textTheme.labelSmall,
                ),
              ),
              if (onCancel != null)
                IconButton(
                  tooltip: 'Отменить',
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: onCancel,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: transfer.progress),
        ],
      ),
    );
  }
}
