import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/chat/chat_manager.dart';
import '../core/chat/sticker_manager.dart';
import '../core/theme/telegram_theme.dart';
import '../models/sticker_models.dart';
import 'sticker_file_image.dart';

/// Встроенная панель стикеров и GIF (выезжает под полем ввода).
class StickerPanelPanel extends StatefulWidget {
  const StickerPanelPanel({
    super.key,
    required this.chatId,
    this.onStickerSent,
    this.height = TelegramSpacing.stickerPanelHeight,
  });

  final int chatId;
  final VoidCallback? onStickerSent;
  final double height;

  @override
  State<StickerPanelPanel> createState() => _StickerPanelPanelState();
}

class _StickerPanelPanelState extends State<StickerPanelPanel>
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
    widget.onStickerSent?.call();
  }

  Future<void> _sendGif(GifSearchResult result) async {
    await context.read<ChatManager>().sendGifInlineResult(
          queryId: result.queryId,
          resultId: result.resultId,
        );
    widget.onStickerSent?.call();
  }

  Future<void> _sendAnimation(AnimationModel animation) async {
    await context.read<ChatManager>().sendAnimation(animation);
    widget.onStickerSent?.call();
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
    final tg = context.telegramTheme;

    return SizedBox(
      height: widget.height,
      child: ColoredBox(
        color: tg.chatListBackground,
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tg.chatListDivider)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabs,
                        isScrollable: true,
                        dividerHeight: 0,
                        indicatorColor: tg.accent,
                        labelColor: tg.accent,
                        unselectedLabelColor: tg.textSecondary,
                        tabAlignment: TabAlignment.start,
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
                      icon: Icon(Icons.visibility_outlined, color: tg.textSecondary),
                    ),
                    IconButton(
                      tooltip: 'Установить набор',
                      onPressed: _showInstallSetDialog,
                      icon: Icon(Icons.add_box_outlined, color: tg.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Consumer<StickerManager>(
                builder: (context, stickers, _) {
                  if (stickers.lastError != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          stickers.lastError!,
                          style: TextStyle(color: tg.textSecondary),
                          textAlign: TextAlign.center,
                        ),
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
                                ? Center(
                                    child: CircularProgressIndicator(
                                      color: tg.accent,
                                      strokeWidth: 2,
                                    ),
                                  )
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
                                ? Center(
                                    child: CircularProgressIndicator(
                                      color: tg.accent,
                                      strokeWidth: 2,
                                    ),
                                  )
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
      ),
    );
  }
}

/// Модальный bottom sheet с панелью стикеров (legacy).
class StickerPanelSheet extends StatelessWidget {
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
      backgroundColor: context.telegramTheme.chatListBackground,
      builder: (_) => StickerPanelSheet(chatId: chatId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.45;
    return StickerPanelPanel(
      chatId: chatId,
      height: height,
      onStickerSent: () => Navigator.maybePop(context),
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
    final tg = context.telegramTheme;

    if (manager.isLoadingSets && manager.installedSets.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: tg.accent, strokeWidth: 2),
      );
    }

    if (manager.installedSets.isEmpty) {
      return Center(
        child: Text(
          'Нет установленных наборов',
          style: TextStyle(color: tg.textSecondary),
        ),
      );
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
                label: Text(
                  set.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? tg.accent : tg.textPrimary,
                    fontSize: TelegramFontSizes.preview,
                  ),
                ),
                selected: selected,
                selectedColor: tg.accent.withValues(alpha: 0.12),
                backgroundColor: tg.inputFieldBackground,
                side: BorderSide(
                  color: selected ? tg.accent : tg.chatListDivider,
                ),
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
                    style: TextStyle(
                      color: tg.textSecondary,
                      fontSize: TelegramFontSizes.preview,
                    ),
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
              ? Center(
                  child: CircularProgressIndicator(
                    color: tg.accent,
                    strokeWidth: 2,
                  ),
                )
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
    final tg = context.telegramTheme;

    if (stickers.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: TextStyle(color: tg.textSecondary),
        ),
      );
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
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onStickerTap(sticker),
            child: StickerFileImage(
              fileId: sticker.fileId,
              emoji: sticker.emoji,
            ),
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
    final tg = context.telegramTheme;

    if (results.isEmpty) {
      return Center(
        child: Text(
          'Введите запрос для поиска GIF',
          style: TextStyle(color: tg.textSecondary),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.1,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        final animation = result.animation;
        return Material(
          color: Colors.transparent,
          child: InkWell(
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
                  style: TextStyle(
                    color: tg.textSecondary,
                    fontSize: TelegramFontSizes.time,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
