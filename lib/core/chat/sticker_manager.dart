import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/sticker_models.dart';
import '../tdlib/tdlib_client.dart';

/// Загрузка стикеров, GIF-поиска и установки наборов.
class StickerManager extends ChangeNotifier {
  StickerManager({required TdlibClient client}) : _client = client;

  final TdlibClient _client;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  final List<StickerSetSummary> _installedSets = [];
  final List<StickerModel> _favoriteStickers = [];
  final List<StickerModel> _recentStickers = [];
  final List<StickerModel> _currentSetStickers = [];
  final List<StickerModel> _searchResults = [];
  final List<GifSearchResult> _gifResults = [];

  StickerSetSummary? _selectedSet;
  StickerSetSummary? _viewingSet;
  var _isLoadingSets = false;
  var _isLoadingStickers = false;
  var _isSearching = false;
  var _isSearchingGifs = false;
  String? _lastError;
  int? _gifBotUserId;
  int _requestId = 0;
  String _gifQuery = '';

  List<StickerSetSummary> get installedSets => List.unmodifiable(_installedSets);
  List<StickerModel> get favoriteStickers =>
      List.unmodifiable(_favoriteStickers);
  List<StickerModel> get recentStickers => List.unmodifiable(_recentStickers);
  List<StickerModel> get currentSetStickers =>
      List.unmodifiable(_currentSetStickers);
  List<StickerModel> get searchResults => List.unmodifiable(_searchResults);
  List<GifSearchResult> get gifResults => List.unmodifiable(_gifResults);
  StickerSetSummary? get selectedSet => _selectedSet;
  StickerSetSummary? get viewingSet => _viewingSet;
  bool get isLoadingSets => _isLoadingSets;
  bool get isLoadingStickers => _isLoadingStickers;
  bool get isSearching => _isSearching;
  bool get isSearchingGifs => _isSearchingGifs;
  String? get lastError => _lastError;

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
    refreshAll();
    _resolveGifBot();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void refreshAll() {
    loadInstalledSets();
    loadFavoriteStickers();
    loadRecentStickers();
  }

  void loadInstalledSets() {
    _isLoadingSets = true;
    _lastError = null;
    notifyListeners();
    final requestId = ++_requestId;
    _client.send({
      '@type': 'getInstalledStickerSets',
      'sticker_type': {'@type': 'stickerTypeRegular'},
      '@extra': 'installedSets_$requestId',
    });
  }

  void loadFavoriteStickers() {
    final requestId = ++_requestId;
    _client.send({
      '@type': 'getFavoriteStickers',
      '@extra': 'favoriteStickers_$requestId',
    });
  }

  void loadRecentStickers() {
    final requestId = ++_requestId;
    _client.send({
      '@type': 'getRecentStickers',
      'attached_to_menu': false,
      '@extra': 'recentStickers_$requestId',
    });
  }

  void selectStickerSet(StickerSetSummary set) {
    _selectedSet = set;
    _isLoadingStickers = true;
    notifyListeners();
    final requestId = ++_requestId;
    _client.send({
      '@type': 'getStickerSet',
      'set_id': set.id,
      '@extra': 'stickerSet_${set.id}_$requestId',
    });
  }

  void viewStickerSetByName(String name) {
    final requestId = ++_requestId;
    _client.send({
      '@type': 'searchStickerSet',
      'title': name,
      '@extra': 'searchSet_$name$requestId',
    });
  }

  void installStickerSet(int setId, {bool archive = false}) {
    _client.send({
      '@type': 'installStickerSet',
      'set_id': setId,
      'is_archived': archive,
    });
    loadInstalledSets();
  }

  void installStickerSetFromLink(String link) {
    final name = StickerLinkParser.parseSetName(link);
    if (name == null) {
      _lastError = 'Не удалось распознать ссылку на набор';
      notifyListeners();
      return;
    }
    final requestId = ++_requestId;
    _client.send({
      '@type': 'searchStickerSet',
      'title': name,
      '@extra': 'installSet_$name$requestId',
    });
  }

  void searchStickers(String query, {int? chatId}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _searchResults.clear();
      notifyListeners();
      return;
    }
    _isSearching = true;
    notifyListeners();
    final requestId = ++_requestId;
    _client.send({
      '@type': 'searchStickers',
      'query': trimmed,
      'offset': 0,
      'limit': 40,
      'sticker_type': {'@type': 'stickerTypeRegular'},
      if (chatId != null) 'chat_id': chatId,
      '@extra': 'searchStickers_$requestId',
    });
  }

  void searchGifs(String query, {required int chatId}) {
    _gifQuery = query.trim();
    if (_gifBotUserId == null) {
      _resolveGifBot(onReady: () => _searchGifs(chatId));
      return;
    }
    _searchGifs(chatId);
  }

  void _searchGifs(int chatId) {
    final botId = _gifBotUserId;
    if (botId == null) {
      _lastError = 'GIF-бот недоступен';
      notifyListeners();
      return;
    }
    _isSearchingGifs = true;
    notifyListeners();
    final requestId = ++_requestId;
    _client.send({
      '@type': 'getInlineQueryResults',
      'bot_user_id': botId,
      'chat_id': chatId,
      'query': _gifQuery,
      'offset': '',
      '@extra': 'gifSearch_$requestId',
    });
  }

  void toggleFavorite(StickerModel sticker, {required bool add}) {
    _client.send({
      '@type': add ? 'addFavoriteSticker' : 'removeFavoriteSticker',
      'sticker': sticker.toInputFileId(),
    });
    loadFavoriteStickers();
  }

  void _resolveGifBot({VoidCallback? onReady}) {
    final requestId = ++_requestId;
    _client.send({
      '@type': 'searchPublicChat',
      'username': 'gif',
      '@extra': 'gifBot_$requestId',
    });
    if (onReady != null) {
      _pendingGifSearch = onReady;
    }
  }

  VoidCallback? _pendingGifSearch;

  void _handleUpdate(Map<String, dynamic> update) {
    final type = update['@type'] as String?;
    final extra = update['@extra'] as String?;

    if (type == 'chat' && extra != null && extra.startsWith('gifBot_')) {
      _gifBotUserId = update['id'] as int?;
      _pendingGifSearch?.call();
      _pendingGifSearch = null;
      return;
    }

    if (type == 'stickerSets' && extra != null && extra.startsWith('installedSets_')) {
      final sets = update['sets'] as List<dynamic>? ?? [];
      _installedSets
        ..clear()
        ..addAll(
          sets.whereType<Map<String, dynamic>>().map(
                StickerSetSummary.fromTdlib,
              ),
        );
      _isLoadingSets = false;
      if (_installedSets.isNotEmpty && _selectedSet == null) {
        selectStickerSet(_installedSets.first);
      }
      notifyListeners();
      return;
    }

    if (type == 'stickers' && extra != null) {
      final stickers = update['stickers'] as List<dynamic>? ?? [];
      final parsed = stickers
          .whereType<Map<String, dynamic>>()
          .map(StickerModel.fromTdlib)
          .toList();

      if (extra.startsWith('favoriteStickers_')) {
        _favoriteStickers
          ..clear()
          ..addAll(parsed);
        notifyListeners();
      } else if (extra.startsWith('recentStickers_')) {
        _recentStickers
          ..clear()
          ..addAll(parsed);
        notifyListeners();
      } else if (extra.startsWith('searchStickers_')) {
        _searchResults
          ..clear()
          ..addAll(parsed);
        _isSearching = false;
        notifyListeners();
      }
      return;
    }

    if (type == 'stickerSet' && extra != null && extra.startsWith('stickerSet_')) {
      final stickers = update['stickers'] as List<dynamic>? ?? [];
      _currentSetStickers
        ..clear()
        ..addAll(
          stickers.whereType<Map<String, dynamic>>().map(StickerModel.fromTdlib),
        );
      _selectedSet = StickerSetSummary.fromTdlib(update);
      _isLoadingStickers = false;
      notifyListeners();
      return;
    }

    if (type == 'stickerSet' &&
        (extra?.startsWith('searchSet_') == true ||
            extra?.startsWith('installSet_') == true)) {
      final summary = StickerSetSummary.fromTdlib(update);
      _viewingSet = summary;
      if (extra!.startsWith('installSet_')) {
        installStickerSet(summary.id);
      }
      selectStickerSet(summary);
      notifyListeners();
      return;
    }

    if (type == 'inlineQueryResults' && extra != null && extra.startsWith('gifSearch_')) {
      final queryId = update['inline_query_id'] as int? ?? 0;
      final results = update['results'] as List<dynamic>? ?? [];
      _gifResults
        ..clear()
        ..addAll(
          results.whereType<Map<String, dynamic>>().map((result) {
            final content = result['content'] as Map<String, dynamic>? ?? {};
            final animationRaw =
                content['animation'] as Map<String, dynamic>? ?? {};
            return GifSearchResult(
              resultId: result['id'] as String? ?? '',
              queryId: queryId,
              title: result['title'] as String? ?? 'GIF',
              animation: AnimationModel.fromTdlib(animationRaw),
            );
          }),
        );
      _isSearchingGifs = false;
      notifyListeners();
      return;
    }

    if (type == 'error' && extra != null) {
      _lastError = update['message'] as String? ?? 'Ошибка стикеров';
      _isLoadingSets = false;
      _isLoadingStickers = false;
      _isSearching = false;
      _isSearchingGifs = false;
      notifyListeners();
    }
  }
}
