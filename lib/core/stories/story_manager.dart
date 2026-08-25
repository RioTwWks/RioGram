import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/story_models.dart';
import '../chat/tdlib_chat_parser.dart';
import '../media/media_cache_manager.dart';
import '../tdlib/tdlib_client.dart';
import 'tdlib_story_parser.dart';

/// Лента историй: загрузка, просмотр, публикация, реакции и ответы.
class StoryManager extends ChangeNotifier {
  StoryManager({
    required TdlibClient client,
    required MediaCacheManager mediaCache,
  })  : _client = client,
        _mediaCache = mediaCache;

  final TdlibClient _client;
  final MediaCacheManager _mediaCache;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  final Map<int, StoryPosterSummary> _postersByChatId = {};
  final Map<String, StoryModel> _storiesByKey = {};
  final List<StoryReactionOption> _availableReactions = [];

  StoryPostState _postState = const StoryPostState();
  String? _lastError;
  int? _savedMessagesChatId;
  int? _viewerPosterChatId;
  int? _viewerStoryId;
  var _isLoadingList = false;

  List<StoryPosterSummary> get posters {
    final list = _postersByChatId.values.toList();
    list.sort((a, b) {
      final orderCompare = b.order.compareTo(a.order);
      if (orderCompare != 0) {
        return orderCompare;
      }
      return b.chatId.compareTo(a.chatId);
    });
    return List.unmodifiable(list);
  }

  StoryPostState get postState => _postState;
  String? get lastError => _lastError;
  bool get isLoadingList => _isLoadingList;
  List<StoryReactionOption> get availableReactions =>
      List.unmodifiable(_availableReactions);

  int? get viewerPosterChatId => _viewerPosterChatId;
  int? get viewerStoryId => _viewerStoryId;

  StoryPosterSummary? posterForChat(int chatId) => _postersByChatId[chatId];

  StoryModel? storyFor(int posterChatId, int storyId) =>
      _storiesByKey['${posterChatId}_$storyId'];

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void setSavedMessagesChatId(int? chatId) {
    _savedMessagesChatId = chatId;
  }

  void loadMainStoryList() {
    _isLoadingList = true;
    _lastError = null;
    notifyListeners();
    _client.send({
      '@type': 'loadActiveStories',
      'story_list': {'@type': 'storyListMain'},
      '@extra': 'story_load_main',
    });
  }

  void refreshPosterStories(int chatId) {
    _client.send({
      '@type': 'getChatActiveStories',
      'chat_id': chatId,
      '@extra': 'story_active_$chatId',
    });
  }

  void loadStory(int posterChatId, int storyId) {
    _client.send({
      '@type': 'getStory',
      'story_poster_chat_id': posterChatId,
      'story_id': storyId,
      'only_local': false,
      '@extra': 'story_get_${posterChatId}_$storyId',
    });
  }

  void openStoryViewer(int posterChatId, int storyId) {
    _viewerPosterChatId = posterChatId;
    _viewerStoryId = storyId;
    _client.send({
      '@type': 'openStory',
      'story_poster_chat_id': posterChatId,
      'story_id': storyId,
      '@extra': 'story_open_${posterChatId}_$storyId',
    });
    loadStory(posterChatId, storyId);
    notifyListeners();
  }

  void closeStoryViewer() {
    final posterChatId = _viewerPosterChatId;
    final storyId = _viewerStoryId;
    _viewerPosterChatId = null;
    _viewerStoryId = null;
    if (posterChatId != null && storyId != null) {
      _client.send({
        '@type': 'closeStory',
        'story_poster_chat_id': posterChatId,
        'story_id': storyId,
        '@extra': 'story_close_${posterChatId}_$storyId',
      });
    }
    notifyListeners();
  }

  void advanceViewerStory(int posterChatId, int storyId) {
    closeStoryViewer();
    openStoryViewer(posterChatId, storyId);
  }

  void checkCanPostStory(int chatId) {
    _client.send({
      '@type': 'canPostStory',
      'chat_id': chatId,
      '@extra': 'story_can_post_$chatId',
    });
  }

  void loadAvailableReactions() {
    if (_availableReactions.isNotEmpty) {
      return;
    }
    _client.send({
      '@type': 'getStoryAvailableReactions',
      'row_size': 8,
      '@extra': 'story_reactions',
    });
  }

  void preparePostStory() {
    final chatId = _savedMessagesChatId;
    if (chatId == null) {
      _postState = _postState.copyWith(
        canPost: false,
        lastError: 'Избранное недоступно для публикации истории',
      );
      notifyListeners();
      return;
    }
    checkCanPostStory(chatId);
    loadAvailableReactions();
  }

  void postPhotoStory({
    required String path,
    String caption = '',
    int activePeriodSeconds = 86400,
  }) {
    final chatId = _savedMessagesChatId;
    if (chatId == null) {
      _lastError = 'Не найден чат «Избранное»';
      notifyListeners();
      return;
    }

    _postState = _postState.copyWith(isPosting: true, lastError: null);
    _lastError = null;
    notifyListeners();

    _client.send({
      '@type': 'postStory',
      'chat_id': chatId,
      'content': {
        '@type': 'inputStoryContentPhoto',
        'photo': {
          '@type': 'inputFileLocal',
          'path': path,
        },
        'added_sticker_file_ids': <int>[],
      },
      'areas': null,
      'caption': caption.isEmpty
          ? null
          : {
              '@type': 'formattedText',
              'text': caption,
              'entities': <Map<String, dynamic>>[],
            },
      'privacy_settings': {
        '@type': 'storyPrivacySettingsEveryone',
        'except_user_ids': <int>[],
      },
      'album_ids': <int>[],
      'active_period': activePeriodSeconds,
      'from_story_full_id': null,
      'is_posted_to_chat_page': true,
      'protect_content': false,
      '@extra': 'story_post_photo',
    });
  }

  void postVideoStory({
    required String path,
    String caption = '',
    int activePeriodSeconds = 86400,
    double durationSeconds = 5,
  }) {
    final chatId = _savedMessagesChatId;
    if (chatId == null) {
      _lastError = 'Не найден чат «Избранное»';
      notifyListeners();
      return;
    }

    _postState = _postState.copyWith(isPosting: true, lastError: null);
    _lastError = null;
    notifyListeners();

    _client.send({
      '@type': 'postStory',
      'chat_id': chatId,
      'content': {
        '@type': 'inputStoryContentVideo',
        'video': {
          '@type': 'inputFileLocal',
          'path': path,
        },
        'added_sticker_file_ids': <int>[],
        'duration': durationSeconds,
        'cover_frame_timestamp': 0,
        'is_animation': false,
      },
      'areas': null,
      'caption': caption.isEmpty
          ? null
          : {
              '@type': 'formattedText',
              'text': caption,
              'entities': <Map<String, dynamic>>[],
            },
      'privacy_settings': {
        '@type': 'storyPrivacySettingsEveryone',
        'except_user_ids': <int>[],
      },
      'album_ids': <int>[],
      'active_period': activePeriodSeconds,
      'from_story_full_id': null,
      'is_posted_to_chat_page': true,
      'protect_content': false,
      '@extra': 'story_post_video',
    });
  }

  void setStoryReaction({
    required int posterChatId,
    required int storyId,
    required String emoji,
  }) {
    _client.send({
      '@type': 'setStoryReaction',
      'story_poster_chat_id': posterChatId,
      'story_id': storyId,
      'reaction_type': {
        '@type': 'reactionTypeEmoji',
        'emoji': emoji,
      },
      'update_recent_reactions': true,
      '@extra': 'story_reaction_${posterChatId}_$storyId',
    });

    final key = '${posterChatId}_$storyId';
    final current = _storiesByKey[key];
    if (current != null) {
      _storiesByKey[key] = current.copyWith(chosenReactionEmoji: emoji);
      notifyListeners();
    }
  }

  void removeStoryReaction({
    required int posterChatId,
    required int storyId,
  }) {
    _client.send({
      '@type': 'setStoryReaction',
      'story_poster_chat_id': posterChatId,
      'story_id': storyId,
      'reaction_type': null,
      'update_recent_reactions': true,
      '@extra': 'story_reaction_${posterChatId}_$storyId',
    });

    final key = '${posterChatId}_$storyId';
    final current = _storiesByKey[key];
    if (current != null) {
      _storiesByKey[key] = current.copyWith(chosenReactionEmoji: null);
      notifyListeners();
    }
  }

  void replyToStory({
    required int posterChatId,
    required int storyId,
    required String text,
  }) {
    if (text.trim().isEmpty) {
      return;
    }

    _client.send({
      '@type': 'sendMessage',
      'chat_id': posterChatId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {
          '@type': 'formattedText',
          'text': text.trim(),
          'entities': <Map<String, dynamic>>[],
        },
      },
      'reply_to': {
        '@type': 'inputMessageReplyToStory',
        'story_poster_chat_id': posterChatId,
        'story_id': storyId,
      },
      '@extra': 'story_reply_${posterChatId}_$storyId',
    });
  }

  void enrichPosterFromChat({
    required int chatId,
    required String title,
    String? avatarLocalPath,
  }) {
    final current = _postersByChatId[chatId];
    if (current == null) {
      return;
    }
    _postersByChatId[chatId] = current.copyWith(
      title: title,
      avatarLocalPath: avatarLocalPath,
    );
    notifyListeners();
  }

  void _handleUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case 'updateChatActiveStories':
        _handleActiveStoriesUpdate(update);
      case 'chatActiveStories':
        _handleActiveStoriesResponse(update);
      case 'story':
        _handleStoryResponse(update);
      case 'updateStory':
        _handleStoryUpdate(update);
      case 'updateStoryDeleted':
        _handleStoryDeleted(update);
      case 'updateStoryPostSucceeded':
        _handleStoryPostSucceeded(update);
      case 'updateStoryPostFailed':
        _handleStoryPostFailed(update);
      case 'availableReactions':
        _handleAvailableReactions(update);
      case 'canPostStoryResultOk':
        _postState = _postState.copyWith(canPost: true, lastError: null);
        notifyListeners();
      case 'canPostStoryResultPremiumNeeded':
        _postState = _postState.copyWith(
          canPost: false,
          lastError: 'Нужен Telegram Premium для публикации истории',
        );
        notifyListeners();
      case 'canPostStoryResultBoostNeeded':
        _postState = _postState.copyWith(
          canPost: false,
          lastError: 'Нужен буст канала для публикации истории',
        );
        notifyListeners();
      case 'canPostStoryResultActiveStoryLimitExceeded':
        _postState = _postState.copyWith(
          canPost: false,
          lastError: 'Достигнут лимит активных историй',
        );
        notifyListeners();
      case 'canPostStoryResultWeeklyLimitExceeded':
      case 'canPostStoryResultMonthlyLimitExceeded':
        _postState = _postState.copyWith(
          canPost: false,
          lastError: 'Достигнут лимит публикаций историй',
        );
        notifyListeners();
      case 'canPostStoryResultLiveStoryIsActive':
        _postState = _postState.copyWith(
          canPost: false,
          lastError: 'Сначала завершите активную live-историю',
        );
        notifyListeners();
      case 'chat':
        _handleChatResponse(update);
      case 'file':
        _handleFileResponse(update);
      case 'ok':
        _handleOk(update);
      case 'error':
        _handleError(update);
    }
  }

  void _handleActiveStoriesUpdate(Map<String, dynamic> update) {
    final raw = update['active_stories'] as Map<String, dynamic>?;
    final poster = TdlibStoryParser.parseChatActiveStories(raw);
    if (poster == null) {
      return;
    }
    _mergePoster(poster);
  }

  void _handleActiveStoriesResponse(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null ||
        (!extra.startsWith('story_active_') && extra != 'story_load_main')) {
      return;
    }
    final poster = TdlibStoryParser.parseChatActiveStories(update);
    if (poster == null) {
      return;
    }
    _mergePoster(poster);
    if (extra == 'story_load_main') {
      _isLoadingList = false;
    }
  }

  void _mergePoster(StoryPosterSummary poster) {
    if (!poster.hasStories) {
      _postersByChatId.remove(poster.chatId);
      notifyListeners();
      return;
    }

    final existing = _postersByChatId[poster.chatId];
    _postersByChatId[poster.chatId] = poster.copyWith(
      title: existing?.title ?? poster.title,
      avatarLocalPath: existing?.avatarLocalPath ?? poster.avatarLocalPath,
    );

    if ((existing?.title ?? '').isEmpty) {
      _client.send({
        '@type': 'getChat',
        'chat_id': poster.chatId,
        '@extra': 'story_chat_${poster.chatId}',
      });
    }

    notifyListeners();
  }

  void _handleStoryResponse(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('story_get_')) {
      return;
    }
    final story = TdlibStoryParser.parseStory(update);
    if (story == null) {
      return;
    }
    _storiesByKey[story.cacheKey] = story;
    final fileId = story.mediaFileId;
    if (fileId != null && story.mediaLocalPath == null) {
      _mediaCache.requestDownload(fileId, priority: 32);
    }
    notifyListeners();
  }

  void _handleStoryUpdate(Map<String, dynamic> update) {
    final raw = update['story'] as Map<String, dynamic>?;
    final story = TdlibStoryParser.parseStory(raw);
    if (story == null) {
      return;
    }
    _storiesByKey[story.cacheKey] = story;
    notifyListeners();
  }

  void _handleStoryDeleted(Map<String, dynamic> update) {
    final posterChatId = update['story_poster_chat_id'];
    final storyId = update['story_id'];
    if (posterChatId == null || storyId == null) {
      return;
    }
    final chatId = posterChatId is int
        ? posterChatId
        : int.tryParse('$posterChatId') ?? 0;
    final id = storyId is int ? storyId : int.tryParse('$storyId') ?? 0;
    _storiesByKey.remove('${chatId}_$id');

    final poster = _postersByChatId[chatId];
    if (poster != null) {
      final stories = poster.stories
          .where((story) => story.storyId != id)
          .toList(growable: false);
      if (stories.isEmpty) {
        _postersByChatId.remove(chatId);
      } else {
        _postersByChatId[chatId] = poster.copyWith(stories: stories);
      }
    }
    notifyListeners();
  }

  void _handleStoryPostSucceeded(Map<String, dynamic> update) {
    _postState = _postState.copyWith(isPosting: false, lastError: null);
    final raw = update['story'] as Map<String, dynamic>?;
    final story = TdlibStoryParser.parseStory(raw);
    if (story != null) {
      _storiesByKey[story.cacheKey] = story;
    }
    loadMainStoryList();
    notifyListeners();
  }

  void _handleStoryPostFailed(Map<String, dynamic> update) {
    _postState = _postState.copyWith(
      isPosting: false,
      lastError: update['error']?['message'] as String? ??
          'Не удалось опубликовать историю',
    );
    notifyListeners();
  }

  void _handleAvailableReactions(Map<String, dynamic> update) {
    if (update['@extra'] != 'story_reactions') {
      return;
    }
    _availableReactions
      ..clear()
      ..addAll(TdlibStoryParser.parseAvailableReactions(update));
    notifyListeners();
  }

  void _handleChatResponse(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('story_chat_')) {
      return;
    }
    final chatId = int.tryParse(extra.substring('story_chat_'.length));
    if (chatId == null) {
      return;
    }
    final title = update['title'] as String? ?? '';
    final avatar = TdlibChatParser.parseAvatar(
      update['photo'] as Map<String, dynamic>?,
    );
    enrichPosterFromChat(
      chatId: chatId,
      title: title,
      avatarLocalPath: avatar.localPath,
    );
  }

  void _handleFileResponse(Map<String, dynamic> update) {
    if (update['@type'] != 'file') {
      return;
    }
    final fileId = update['id'];
    if (fileId == null) {
      return;
    }
    final parsedId = fileId is int ? fileId : int.tryParse('$fileId');
    if (parsedId == null) {
      return;
    }
    final local = update['local'] as Map<String, dynamic>?;
    final path = local?['path'] as String?;
    final completed = local?['is_downloading_completed'] as bool? ?? false;
    if (!completed || path == null || path.isEmpty) {
      return;
    }

    var changed = false;
    for (final entry in _storiesByKey.entries) {
      if (entry.value.mediaFileId == parsedId &&
          entry.value.mediaLocalPath != path) {
        _storiesByKey[entry.key] = entry.value.copyWith(mediaLocalPath: path);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void _handleOk(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == 'story_load_main') {
      _isLoadingList = false;
      notifyListeners();
    }
  }

  void _handleError(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('story_')) {
      return;
    }
    final message = update['message'] as String? ?? 'Ошибка историй';
    if (extra == 'story_load_main') {
      _isLoadingList = false;
    }
    if (extra.startsWith('story_post_')) {
      _postState = _postState.copyWith(isPosting: false, lastError: message);
    }
    _lastError = message;
    notifyListeners();
  }
}
