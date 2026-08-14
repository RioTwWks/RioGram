import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/media/media_cache_manager.dart';
import '../../models/cache_models.dart';

/// Настройки кэша и автозагрузки медиа.
class StorageSettingsSection extends StatelessWidget {
  const StorageSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cache = context.watch<MediaCacheManager?>();
    if (cache == null) {
      return const SizedBox.shrink();
    }

    final stats = cache.storageStats;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Кэш и автозагрузка',
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Обновить статистику',
              onPressed: cache.isLoadingStats
                  ? null
                  : cache.refreshStorageStatistics,
              icon: cache.isLoadingStats
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (cache.lastError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              cache.lastError!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Хранилище', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (stats != null) ...[
                  _StatRow(label: 'Всего', value: stats.totalSize),
                  _StatRow(label: 'Фото', value: stats.photoSize),
                  _StatRow(label: 'Видео', value: stats.videoSize),
                  _StatRow(label: 'Аудио', value: stats.audioSize),
                  _StatRow(label: 'Документы', value: stats.documentSize),
                ] else
                  const Text('Статистика загружается…'),
                if (cache.filesDirectory != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Каталог: ${cache.filesDirectory}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Сеть: ${cache.currentNetwork.label}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Text('Автозагрузка', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ...DownloadNetworkType.values.map(
          (network) => _AutoDownloadCard(
            cache: cache,
            networkType: network,
          ),
        ),
        const SizedBox(height: 16),
        Text('Очистка кэша', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: cache.isOptimizing ? null : cache.clearPhotosCache,
              child: const Text('Фото'),
            ),
            OutlinedButton(
              onPressed: cache.isOptimizing ? null : cache.clearVideosCache,
              child: const Text('Видео'),
            ),
            OutlinedButton(
              onPressed: cache.isOptimizing ? null : cache.clearAudioCache,
              child: const Text('Аудио'),
            ),
            OutlinedButton(
              onPressed: cache.isOptimizing ? null : cache.clearDocumentsCache,
              child: const Text('Документы'),
            ),
            FilledButton.tonal(
              onPressed: cache.isOptimizing ? null : cache.clearAllMediaCache,
              child: Text(cache.isOptimizing ? 'Очистка…' : 'Очистить всё'),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(StorageStatisticsModel.formatBytes(value)),
        ],
      ),
    );
  }
}

class _AutoDownloadCard extends StatefulWidget {
  const _AutoDownloadCard({
    required this.cache,
    required this.networkType,
  });

  final MediaCacheManager cache;
  final DownloadNetworkType networkType;

  @override
  State<_AutoDownloadCard> createState() => _AutoDownloadCardState();
}

class _AutoDownloadCardState extends State<_AutoDownloadCard> {
  AutoDownloadSettingsModel? _draft;

  AutoDownloadSettingsModel get _settings =>
      _draft ?? widget.cache.settingsFor(widget.networkType);

  Future<void> _save(AutoDownloadSettingsModel value) async {
    setState(() => _draft = value);
    await widget.cache.saveAutoDownloadSettings(value);
    if (mounted) {
      setState(() => _draft = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(widget.networkType.label),
        subtitle: Text(
          settings.isEnabled ? 'Автозагрузка включена' : 'Только вручную',
        ),
        children: [
          SwitchListTile(
            title: const Text('Автозагрузка'),
            value: settings.isEnabled,
            onChanged: (value) =>
                _save(settings.copyWith(isEnabled: value)),
          ),
          ListTile(
            title: const Text('Фото до'),
            subtitle: Slider(
              value: _mbValue(settings.maxPhotoBytes).toDouble(),
              min: 0,
              max: 20,
              divisions: 20,
              label: '${_mbValue(settings.maxPhotoBytes)} MB',
              onChanged: settings.isEnabled
                  ? (value) => _save(
                        settings.copyWith(
                          maxPhotoBytes: value.round() * AutoDownloadSettingsModel.mb1,
                        ),
                      )
                  : null,
            ),
          ),
          ListTile(
            title: const Text('Видео до'),
            subtitle: Slider(
              value: _mbValue(settings.maxVideoBytes).toDouble(),
              min: 0,
              max: 20,
              divisions: 20,
              label: '${_mbValue(settings.maxVideoBytes)} MB',
              onChanged: settings.isEnabled
                  ? (value) => _save(
                        settings.copyWith(
                          maxVideoBytes: value.round() * AutoDownloadSettingsModel.mb1,
                        ),
                      )
                  : null,
            ),
          ),
          ListTile(
            title: const Text('Файлы до'),
            subtitle: Slider(
              value: _mbValue(settings.maxOtherBytes).toDouble(),
              min: 0,
              max: 20,
              divisions: 20,
              label: '${_mbValue(settings.maxOtherBytes)} MB',
              onChanged: settings.isEnabled
                  ? (value) => _save(
                        settings.copyWith(
                          maxOtherBytes: value.round() * AutoDownloadSettingsModel.mb1,
                        ),
                      )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  int _mbValue(int bytes) => (bytes / AutoDownloadSettingsModel.mb1).round();
}
