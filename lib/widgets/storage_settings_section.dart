import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/media/media_cache_manager.dart';
import '../core/theme/telegram_theme.dart';
import '../models/cache_models.dart';
import 'telegram_settings_tile.dart';

class StorageSettingsSection extends StatelessWidget {
  const StorageSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cache = context.watch<MediaCacheManager?>();
    if (cache == null) return const SizedBox.shrink();

    final stats = cache.storageStats;
    final tg = context.telegramTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: TelegramSettingsSectionHeader('Кэш и автозагрузка')),
            IconButton(
              tooltip: 'Обновить статистику',
              onPressed: cache.isLoadingStats ? null : cache.refreshStorageStatistics,
              icon: cache.isLoadingStats
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        if (cache.lastError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(cache.lastError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        TelegramSettingsGroup(
          children: [
            if (stats != null) ...[
              _StatRow(label: 'Всего', value: stats.totalSize),
              _StatRow(label: 'Фото', value: stats.photoSize),
              _StatRow(label: 'Видео', value: stats.videoSize),
              _StatRow(label: 'Аудио', value: stats.audioSize),
              _StatRow(label: 'Документы', value: stats.documentSize, showDivider: cache.filesDirectory == null),
            ] else
              const TelegramSettingsTile(title: 'Статистика загружается…', showChevron: false, showDivider: false),
            if (cache.filesDirectory != null)
              TelegramSettingsTile(title: 'Каталог', subtitle: cache.filesDirectory, showChevron: false, showDivider: false, dense: true),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text('Сеть: ${cache.currentNetwork.label}', style: TextStyle(fontSize: TelegramFontSizes.chatSubtitle, color: tg.textSecondary)),
        ),
        const TelegramSettingsSectionHeader('Автозагрузка'),
        ...DownloadNetworkType.values.map((network) => _AutoDownloadCard(cache: cache, networkType: network)),
        const TelegramSettingsSectionHeader('Очистка кэша'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(onPressed: cache.isOptimizing ? null : cache.clearPhotosCache, child: const Text('Фото')),
            OutlinedButton(onPressed: cache.isOptimizing ? null : cache.clearVideosCache, child: const Text('Видео')),
            OutlinedButton(onPressed: cache.isOptimizing ? null : cache.clearAudioCache, child: const Text('Аудио')),
            OutlinedButton(onPressed: cache.isOptimizing ? null : cache.clearDocumentsCache, child: const Text('Документы')),
            FilledButton.tonal(onPressed: cache.isOptimizing ? null : cache.clearAllMediaCache, child: Text(cache.isOptimizing ? 'Очистка…' : 'Очистить всё')),
          ],
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.showDivider = true});
  final String label;
  final int value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: TelegramFontSizes.chatTitle, color: tg.textPrimary))),
              Text(StorageStatisticsModel.formatBytes(value), style: TextStyle(fontSize: TelegramFontSizes.preview, color: tg.textSecondary)),
            ],
          ),
        ),
        if (showDivider) const TelegramSettingsDivider(),
      ],
    );
  }
}

class _AutoDownloadCard extends StatefulWidget {
  const _AutoDownloadCard({required this.cache, required this.networkType});
  final MediaCacheManager cache;
  final DownloadNetworkType networkType;
  @override
  State<_AutoDownloadCard> createState() => _AutoDownloadCardState();
}

class _AutoDownloadCardState extends State<_AutoDownloadCard> {
  AutoDownloadSettingsModel? _draft;
  AutoDownloadSettingsModel get _settings => _draft ?? widget.cache.settingsFor(widget.networkType);

  Future<void> _save(AutoDownloadSettingsModel value) async {
    setState(() => _draft = value);
    await widget.cache.saveAutoDownloadSettings(value);
    if (mounted) setState(() => _draft = null);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Column(
      children: [
        TelegramSettingsGroup(
          children: [
            TelegramSettingsSwitchTile(
              title: widget.networkType.label,
              subtitle: settings.isEnabled ? 'Автозагрузка включена' : 'Только вручную',
              value: settings.isEnabled,
              onChanged: (value) => _save(settings.copyWith(isEnabled: value)),
            ),
            _SliderRow(title: 'Фото до', mbValue: _mbValue(settings.maxPhotoBytes), enabled: settings.isEnabled, onChanged: (value) => _save(settings.copyWith(maxPhotoBytes: value * AutoDownloadSettingsModel.mb1))),
            _SliderRow(title: 'Видео до', mbValue: _mbValue(settings.maxVideoBytes), enabled: settings.isEnabled, onChanged: (value) => _save(settings.copyWith(maxVideoBytes: value * AutoDownloadSettingsModel.mb1))),
            _SliderRow(title: 'Файлы до', mbValue: _mbValue(settings.maxOtherBytes), enabled: settings.isEnabled, showDivider: false, onChanged: (value) => _save(settings.copyWith(maxOtherBytes: value * AutoDownloadSettingsModel.mb1))),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  int _mbValue(int bytes) => (bytes / AutoDownloadSettingsModel.mb1).round();
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({required this.title, required this.mbValue, required this.enabled, required this.onChanged, this.showDivider = true});
  final String title;
  final int mbValue;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: TelegramFontSizes.chatTitle, color: tg.textPrimary)),
              Slider(value: mbValue.toDouble(), min: 0, max: 20, divisions: 20, label: '$mbValue MB', onChanged: enabled ? (value) => onChanged(value.round()) : null),
            ],
          ),
        ),
        if (showDivider) const TelegramSettingsDivider(),
      ],
    );
  }
}
