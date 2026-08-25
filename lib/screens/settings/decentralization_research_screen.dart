import 'package:flutter/material.dart';

import '../../models/decentralization_models.dart';
import '../../widgets/telegram_settings_tile.dart';

/// Обзор исследований децентрализованной модели (§7.6).
class DecentralizationResearchScreen extends StatelessWidget {
  const DecentralizationResearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = DecentralizationResearchCatalog.items;

    return Scaffold(
      appBar: AppBar(title: const Text('Децентрализация')),
      body: TelegramSettingsListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'RioGram остаётся TDLib-first клиентом. Ниже — долгосрочные '
              'направления исследований без изменения MTProto.',
              style: TextStyle(fontSize: 14),
            ),
          ),
          const TelegramSettingsSectionHeader('Дорожная карта'),
          TelegramSettingsGroup(
            children: [
              for (var i = 0; i < items.length; i++)
                _ResearchTile(
                  item: items[i],
                  showDivider: i < items.length - 1,
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Подробности: docs/DECENTRALIZATION.md',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResearchTile extends StatelessWidget {
  const _ResearchTile({
    required this.item,
    required this.showDivider,
  });

  final DecentralizationRoadmapItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final track = DecentralizationResearchCatalog.trackLabel(item.track);
    final phase = DecentralizationResearchCatalog.phaseLabel(item.phase);

    return TelegramSettingsTile(
      title: item.title,
      subtitle: '$track · $phase\n${item.summary}',
      showChevron: false,
      showDivider: showDivider,
      onTap: () => _showDetails(context),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(item.summary),
              if (item.dependencies.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Зависимости',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...item.dependencies.map((dep) => Text('• $dep')),
              ],
              const SizedBox(height: 16),
              const Text(
                'Риски',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...item.risks.map((risk) => Text('• $risk')),
            ],
          ),
        );
      },
    );
  }
}
