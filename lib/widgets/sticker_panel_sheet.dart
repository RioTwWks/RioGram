import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/chat/chat_manager.dart';
import '../core/chat/sticker_manager.dart';
import '../models/sticker_models.dart';
import 'sticker_file_image.dart';

/// Панель стикеров и GIF-поиска.
class StickerPanelSheet extends StatefulWidget {
  const StickerPanelSheet({
    super.key,
    required this.chatId,
  });

  final int chatId;

  static Future<void> show(BuildContext context, {required int chatId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StickerPanelSheet(chatId: chatId),
    );
  }

  @override
  State<StickerPanelSheet> createState() => _StickerPanelSheetState();
}

class _StickerPanelSheetState extends State<StickerPanelSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();
  final _gifController = TextEditingController();
  final _linkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _searchController.addListener(_onStickerSearchChanged);
    _gifController.addListener(_onGifSearchChanged);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController
      ..removeListener(_onStickerSearchChanged)
      ..dispose();
    _gifController
      ..removeListener(_onGifSearchChanged)
      ..dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _onStickerSearchChanged() {
    context.read<StickerManager>().searchStickers(
          _searchController.text,
          chatId: widget.chatId,
        );
  }

  void _onGifSearchChanged() {
    context.read<StickerManager>().searchGifs(
          _gifController.text,
          chatId: widget.chatId,
        );
  }

  Future<void> _sendSticker(StickerModel sticker) async {
    await context.read<ChatManager>().sendSticker(sticker);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _sendGif(GifSearchResult result) async {
    await context.read<ChatManager>().sendGifInlineResult(
          queryId: result.queryId,
          resultId: result.resultId,
        );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _sendAnimation(AnimationModel animation) async {
    await context.read<ChatManager>().sendAnimation(animation);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _showInstallSetDialog() async {
    _linkController.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Установить набор'),
        content: TextField(
          controller: _linkController,
          decoration: const InputDecoration(
            hintText: 't.me/addstickers/Name',
            labelText: 'Ссылка на стикерпак',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              context
                  .read<StickerManager>()
                  .installStickerSetFromLink(_linkController.text);
              Navigator.pop(dialogContext);
            },
            child: const Text('Установить'),
          ),
        ],
      ),
    );
  }

  Future<void> _showViewSetDialog() async {
    _linkController.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Просмотр набора'),
        content: TextField(
          controller: _linkController,
          decoration: const InputDecoration(
            hintText: 'Имя набора или ссылка',
            labelText: 'Стикерпак',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final name = StickerLinkParser.parseSetName(_linkController.text) ??
                  _linkController.text.trim();
              if (name.isNotEmpty) {
                context.read<StickerManager>().viewStickerSetByName(name);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Открыть'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.45;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Наборы'),
                      Tab(icon: Icon(Icons.star_outline, size: 20)),
                      Tab(icon: Icon(Icons.history, size: 20)),
                      Tab(icon: Icon(Icons.search, size: 20)),
                      Tab(text: 'GIF'),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Просмотр набора',
                  onPressed: _showViewSetDialog,
                  icon: const Icon(Icons.visibility_outlined),
                ),
                IconButton(
                  tooltip: 'Установить набор',
                  onPressed: _showInstallSetDialog,
                  icon: const Icon(Icons.add_box_outlined),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<StickerManager>(
              builder: (context, stickers, _) {
                if (stickers.lastError != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(stickers.lastError!),
                    ),
                  );
                }

                return TabBarView(
                  controller: _tabs,
                  children: [
                    _StickerSetsTab(
                      manager: stickers,
                      onStickerTap: _sendSticker,
                    ),
                    _StickerGridTab(
                      stickers: stickers.favoriteStickers,
                      emptyLabel: 'Нет избранных стикеров',
                      onStickerTap: _sendSticker,
                    ),
                    _StickerGridTab(
                      stickers: stickers.recentStickers,
                      emptyLabel: 'Нет недавних стикеров',
                      onStickerTap: _sendSticker,
                    ),
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Поиск стикеров…',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: stickers.isSearching
                              ? const Center(child: CircularProgressIndicator())
                              : _StickerGridTab(
                                  stickers: stickers.searchResults,
                                  emptyLabel: 'Введите запрос для поиска',
                                  onStickerTap: _sendSticker,
                                ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: TextField(
                            controller: _gifController,
                            decoration: const InputDecoration(
                              hintText: 'Поиск GIF…',
                              prefixIcon: Icon(Icons.gif_box_outlined),
                              isDense: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: stickers.isSearchingGifs
                              ? const Center(child: CircularProgressIndicator())
                              : _GifGridTab(
                                  results: stickers.gifResults,
                                  onGifTap: _sendGif,
                                  onAnimationTap: _sendAnimation,
                                ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StickerSetsTab extends StatelessWidget {
  const _StickerSetsTab({
    required this.manager,
    required this.onStickerTap,
  });

  final StickerManager manager;
  final Future<void> Function(StickerModel sticker) onStickerTap;

  @override
  Widget build(BuildContext context) {
    if (manager.isLoadingSets && manager.installedSets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (manager.installedSets.isEmpty) {
      return const Center(child: Text('Нет установленных наборов'));
    }

    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: manager.installedSets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (context, index) {
              final set = manager.installedSets[index];
              final selected = manager.selectedSet?.id == set.id;
              return ChoiceChip(
                label: Text(set.title, overflow: TextOverflow.ellipsis),
                selected: selected,
                onSelected: (_) => manager.selectStickerSet(set),
              );
            },
          ),
        ),
        if (manager.viewingSet != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Набор: ${manager.viewingSet!.title}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                if (!manager.viewingSet!.isInstalled)
                  TextButton(
                    onPressed: () =>
                        manager.installStickerSet(manager.viewingSet!.id),
                    child: const Text('Установить'),
                  ),
              ],
            ),
          ),
        Expanded(
          child: manager.isLoadingStickers
              ? const Center(child: CircularProgressIndicator())
              : _StickerGridTab(
                  stickers: manager.currentSetStickers,
                  emptyLabel: 'Набор пуст',
                  onStickerTap: onStickerTap,
                ),
        ),
      ],
    );
  }
}

class _StickerGridTab extends StatelessWidget {
  const _StickerGridTab({
    required this.stickers,
    required this.emptyLabel,
    required this.onStickerTap,
  });

  final List<StickerModel> stickers;
  final String emptyLabel;
  final Future<void> Function(StickerModel sticker) onStickerTap;

  @override
  Widget build(BuildContext context) {
    if (stickers.isEmpty) {
      return Center(child: Text(emptyLabel));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final sticker = stickers[index];
        return InkWell(
          onTap: () => onStickerTap(sticker),
          child: StickerFileImage(
            fileId: sticker.fileId,
            emoji: sticker.emoji,
          ),
        );
      },
    );
  }
}

class _GifGridTab extends StatelessWidget {
  const _GifGridTab({
    required this.results,
    required this.onGifTap,
    required this.onAnimationTap,
  });

  final List<GifSearchResult> results;
  final Future<void> Function(GifSearchResult result) onGifTap;
  final Future<void> Function(AnimationModel animation) onAnimationTap;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Center(child: Text('Введите запрос для поиска GIF'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.2,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        final animation = result.animation;
        return InkWell(
          onTap: () => onGifTap(result),
          onLongPress: () => onAnimationTap(animation),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StickerFileImage(
                  fileId: animation.thumbnailFileId ?? animation.fileId,
                  emoji: '🎞',
                  fit: BoxFit.cover,
                ),
              ),
              Text(
                result.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
