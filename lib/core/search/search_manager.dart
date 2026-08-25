import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/chat_models.dart';
import '../../models/group_models.dart';
import '../../models/search_models.dart';
import '../tdlib/tdlib_client.dart';
import 'tdlib_search_parser.dart';

/// Глобальный поиск, discovery и поиск сообщений в чате.
class SearchManager extends ChangeNotifier {
  SearchManager({required TdlibClient client}) : _client = client;

  final TdlibClient _client;

  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _globalDebounce;
  Timer? _newChatDebounce;
  Timer? _chatSearchDebounce;

  String _globalQuery = '';
  SearchMessageFilterKind _globalFilter = SearchMessageFilterKind.all;
  List<int> _globalChatIds = [];
  List<SearchMessageHit> _globalMessages = [];
  List<int> _publicChatIds = [];
  SearchUserHit? _globalUserHit;
  String _globalMessagesOffset = '';
  var _globalHasMoreMessages = false;
  var _globalIsLoading = false;
  var _globalIsLoadingMore = false;
  String? _globalError;
  int _globalRequestId = 0;
  int _pendingGlobalRequests = 0;

  List<int> _newChatSearchIds = [];
  final Set<int> _newChatSearchPublicIds = {};
  SearchUserHit? _newChatUserHit;
  var _newChatIsLoading = false;
  int _newChatRequestId = 0;
  int _pendingNewChatRequests = 0;

  int? _chatSearchChatId;
  int? _chatSearchForumTopicId;
  ChatMessageSearchState _chatSearchState = const ChatMessageSearchState();
  int _chatSearchRequestId = 0;
  int _chatSearchNextFromMessageId = 0;

  final Map<int, String> _chatTitles = {};

  String get globalQuery => _globalQuery;
  SearchMessageFilterKind get globalFilter => _globalFilter;
  bool get isGlobalSearchActive => _globalQuery.isNotEmpty;
  bool get isGlobalLoading => _globalIsLoading;
  bool get isGlobalLoadingMore => _globalIsLoadingMore;
  bool get globalHasMoreMessages => _globalHasMoreMessages;
  String? get globalError => _globalError;
  List<int> get globalChatIds => List.unmodifiable(_globalChatIds);
  List<SearchMessageHit> get globalMessageResults =>
      List.unmodifiable(_globalMessages);
  List<int> get publicChatIds => List.unmodifiable(_publicChatIds);
  SearchUserHit? get globalUserHit => _globalUserHit;
  ChatMessageSearchState get chatSearchState => _chatSearchState;
  List<int> get newChatSearchIds => List.unmodifiable(_newChatSearchIds);
  SearchUserHit? get newChatUserHit => _newChatUserHit;
  bool get isNewChatSearchLoading => _newChatIsLoading;

  String? chatTitleFor(int chatId) => _chatTitles[chatId];

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _globalDebounce?.cancel();
    _newChatDebounce?.cancel();
    _chatSearchDebounce?.cancel();
    super.dispose();
  }

  void setGlobalQuery(String query) {
    _globalQuery = query.trim();
    _globalDebounce?.cancel();

    if (_globalQuery.isEmpty) {
      _clearGlobalResults();
      notifyListeners();
      return;
    }

    _globalIsLoading = true;
    _globalError = null;
    notifyListeners();
    _globalDebounce = Timer(const Duration(milliseconds: 350), _performGlobalSearch);
  }

  void setGlobalFilter(SearchMessageFilterKind filter) {
    if (_globalFilter == filter) {
      return;
    }
    _globalFilter = filter;
    if (_globalQuery.isEmpty) {
      notifyListeners();
      return;
    }
    _performGlobalSearch();
  }

  void clearGlobalSearch() {
    _globalDebounce?.cancel();
    _globalQuery = '';
    _clearGlobalResults();
    notifyListeners();
  }

  void loadMoreGlobalMessages() {
    if (!_globalHasMoreMessages ||
        _globalIsLoading ||
        _globalIsLoadingMore ||
        _globalMessagesOffset.isEmpty) {
      return;
    }
    _globalIsLoadingMore = true;
    notifyListeners();
    final requestId = ++_globalRequestId;
    _client.send({
      '@type': 'searchMessages',
      'chat_list': const ChatListMain().toTdlib(),
      'query': _globalQuery,
      'offset': _globalMessagesOffset,
      'limit': 20,
      'filter': _globalFilter.toTdlib(),
      'min_date': 0,
      'max_date': 0,
      '@extra': 'searchMessagesMore_$requestId',
    });
  }

  void searchForNewChat(String query) {
    _newChatDebounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      clearNewChatSearch();
      return;
    }

    _newChatUserHit = null;
    _newChatIsLoading = true;
    notifyListeners();
    _newChatDebounce = Timer(const Duration(milliseconds: 350), () {
      final requestId = ++_newChatRequestId;
      _newChatSearchIds = [];
      _newChatSearchPublicIds.clear();
      var pending = 4;

      _client.send({
        '@type': 'searchChats',
        'query': trimmed,
        'limit': 20,
        '@extra': 'newChatSearchLocal_$requestId',
      });
      _client.send({
        '@type': 'searchChatsOnServer',
        'query': trimmed,
        'limit': 20,
        '@extra': 'newChatSearch_$requestId',
      });
      _client.send({
        '@type': 'searchPublicChats',
        'query': trimmed,
        'type_filter': {'@type': 'searchChatTypeFilterChannel'},
        '@extra': 'newChatPublicChatsChannel_$requestId',
      });
      _client.send({
        '@type': 'searchPublicChats',
        'query': trimmed,
        'type_filter': {'@type': 'searchChatTypeFilterBot'},
        '@extra': 'newChatPublicChatsBot_$requestId',
      });

      final username = PublicChatLinkParser.parseUsername(trimmed);
      if (username != null) {
        pending += 1;
        _client.send({
          '@type': 'searchPublicChat',
          'username': username,
          '@extra': 'newChatPublic_$requestId',
        });
      }

      final phone = TdlibSearchParser.parsePhoneNumber(trimmed);
      if (phone != null) {
        pending += 1;
        _client.send({
          '@type': 'searchUserByPhoneNumber',
          'phone_number': phone,
          'only_local': false,
          '@extra': 'newChatPhone_$requestId',
        });
      }

      final token = TdlibSearchParser.parseInviteToken(trimmed);
      if (token != null) {
        pending += 1;
        _client.send({
          '@type': 'searchUserByToken',
          'token': token,
          '@extra': 'newChatToken_$requestId',
        });
      }

      _pendingNewChatRequests = pending;
    });
  }

  void clearNewChatSearch() {
    _newChatDebounce?.cancel();
    _newChatSearchIds = [];
    _newChatSearchPublicIds.clear();
    _newChatUserHit = null;
    _newChatIsLoading = false;
    _pendingNewChatRequests = 0;
    notifyListeners();
  }

  bool newChatSearchNeedsJoin(int chatId) {
    if (!_newChatSearchPublicIds.contains(chatId)) {
      return false;
    }
    return true;
  }

  bool isPublicDiscoveryChat(int chatId) =>
      _newChatSearchPublicIds.contains(chatId);

  void setChatSearchQuery(
    int chatId,
    String query, {
    int? forumTopicId,
    SearchMessageFilterKind? filter,
  }) {
    _chatSearchChatId = chatId;
    _chatSearchForumTopicId = forumTopicId;
    final trimmed = query.trim();
    final nextFilter = filter ?? _chatSearchState.filter;

    _chatSearchDebounce?.cancel();
    if (trimmed.isEmpty) {
      _chatSearchState = const ChatMessageSearchState();
      notifyListeners();
      return;
    }

    _chatSearchState = _chatSearchState.copyWith(
      query: trimmed,
      filter: nextFilter,
      isLoading: true,
      error: null,
      results: const [],
      hasMore: false,
    );
    notifyListeners();

    _chatSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      _chatSearchNextFromMessageId = 0;
      _requestChatMessageSearch(reset: true);
    });
  }

  void setChatSearchFilter(SearchMessageFilterKind filter) {
    if (_chatSearchChatId == null || _chatSearchState.query.isEmpty) {
      _chatSearchState = _chatSearchState.copyWith(filter: filter);
      notifyListeners();
      return;
    }
    setChatSearchQuery(
      _chatSearchChatId!,
      _chatSearchState.query,
      forumTopicId: _chatSearchForumTopicId,
      filter: filter,
    );
  }

  void loadMoreChatMessages() {
    if (_chatSearchChatId == null ||
        !_chatSearchState.hasMore ||
        _chatSearchState.isLoading ||
        _chatSearchState.isLoadingMore) {
      return;
    }
    _chatSearchState = _chatSearchState.copyWith(isLoadingMore: true);
    notifyListeners();
    _requestChatMessageSearch(reset: false);
  }

  void clearChatSearch() {
    _chatSearchDebounce?.cancel();
    _chatSearchChatId = null;
    _chatSearchForumTopicId = null;
    _chatSearchNextFromMessageId = 0;
    _chatSearchState = const ChatMessageSearchState();
    notifyListeners();
  }

  void _performGlobalSearch() {
    final requestId = ++_globalRequestId;
    _globalChatIds = [];
    _globalMessages = [];
    _publicChatIds = [];
    _globalUserHit = null;
    _globalMessagesOffset = '';
    _globalHasMoreMessages = false;
    _globalIsLoading = true;
    _globalError = null;

    var pending = 4;
    _pendingGlobalRequests = pending;

    _client.send({
      '@type': 'searchChats',
      'query': _globalQuery,
      'limit': 20,
      '@extra': 'searchChats_$requestId',
    });
    _client.send({
      '@type': 'searchMessages',
      'chat_list': const ChatListMain().toTdlib(),
      'query': _globalQuery,
      'offset': '',
      'limit': 20,
      'filter': _globalFilter.toTdlib(),
      'min_date': 0,
      'max_date': 0,
      '@extra': 'searchMessages_$requestId',
    });
    _client.send({
      '@type': 'searchPublicChats',
      'query': _globalQuery,
      'type_filter': {'@type': 'searchChatTypeFilterChannel'},
      '@extra': 'searchPublicChatsChannel_$requestId',
    });
    _client.send({
      '@type': 'searchPublicChats',
      'query': _globalQuery,
      'type_filter': {'@type': 'searchChatTypeFilterBot'},
      '@extra': 'searchPublicChatsBot_$requestId',
    });

    final username = PublicChatLinkParser.parseUsername(_globalQuery);
    if (username != null) {
      pending += 1;
      _client.send({
        '@type': 'searchPublicChat',
        'username': username,
        '@extra': 'searchPublicChat_$requestId',
      });
    }

    final phone = TdlibSearchParser.parsePhoneNumber(_globalQuery);
    if (phone != null) {
      pending += 1;
      _client.send({
        '@type': 'searchUserByPhoneNumber',
        'phone_number': phone,
        'only_local': false,
        '@extra': 'searchUserPhone_$requestId',
      });
    }

    final token = TdlibSearchParser.parseInviteToken(_globalQuery);
    if (token != null) {
      pending += 1;
      _client.send({
        '@type': 'searchUserByToken',
        'token': token,
        '@extra': 'searchUserToken_$requestId',
      });
    }

    _pendingGlobalRequests = pending;
    notifyListeners();
  }

  void _requestChatMessageSearch({required bool reset}) {
    final chatId = _chatSearchChatId;
    if (chatId == null) {
      return;
    }

    final requestId = ++_chatSearchRequestId;
    final request = <String, dynamic>{
      '@type': 'searchChatMessages',
      'chat_id': chatId,
      'query': _chatSearchState.query,
      'from_message_id': reset ? 0 : _chatSearchNextFromMessageId,
      'offset': 0,
      'limit': 30,
      'filter': _chatSearchState.filter.toTdlib(),
      '@extra': reset
          ? 'chatSearch_$requestId'
          : 'chatSearchMore_$requestId',
    };

    final forumTopicId = _chatSearchForumTopicId;
    if (forumTopicId != null) {
      request['topic_id'] = {
        '@type': 'messageTopicForum',
        'forum_topic_id': forumTopicId,
      };
    }

    _client.send(request);
  }

  void _clearGlobalResults() {
    _globalChatIds = [];
    _globalMessages = [];
    _publicChatIds = [];
    _globalUserHit = null;
    _globalMessagesOffset = '';
    _globalHasMoreMessages = false;
    _globalIsLoading = false;
    _globalIsLoadingMore = false;
    _globalError = null;
    _pendingGlobalRequests = 0;
  }

  void _handleUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case 'chats':
        _handleChats(update);
      case 'foundMessages':
        _handleFoundMessages(update);
      case 'foundChatMessages':
        _handleFoundChatMessages(update);
      case 'chat':
        _handleChat(update);
      case 'user':
        _handleUser(update);
      case 'error':
        _handleError(update);
    }
  }

  void _handleChats(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null) {
      return;
    }

    final chatIds = TdlibSearchParser.parseChatIds(update);

    if (extra.startsWith('searchChats_')) {
      final requestId = int.tryParse(extra.substring('searchChats_'.length));
      if (requestId != _globalRequestId) {
        return;
      }
      _globalChatIds = chatIds;
      _ensureChatTitles(chatIds);
      _completeGlobalRequest();
      return;
    }

    if (extra.startsWith('searchPublicChatsChannel_') ||
        extra.startsWith('searchPublicChatsBot_')) {
      final prefix = extra.startsWith('searchPublicChatsChannel_')
          ? 'searchPublicChatsChannel_'
          : 'searchPublicChatsBot_';
      final requestId = int.tryParse(extra.substring(prefix.length));
      if (requestId != _globalRequestId) {
        return;
      }
      _publicChatIds = {..._publicChatIds, ...chatIds}.toList();
      for (final id in chatIds) {
        _newChatSearchPublicIds.add(id);
      }
      _ensureChatTitles(chatIds);
      _completeGlobalRequest();
      return;
    }

    if (extra.startsWith('newChatSearchLocal_') ||
        extra.startsWith('newChatSearch_') ||
        extra.startsWith('newChatPublicChatsChannel_') ||
        extra.startsWith('newChatPublicChatsBot_')) {
      final requestId = _newChatRequestIdFromExtra(extra);
      if (requestId != _newChatRequestId) {
        return;
      }
      _newChatSearchIds = {..._newChatSearchIds, ...chatIds}.toList();
      if (extra.contains('PublicChats')) {
        _newChatSearchPublicIds.addAll(chatIds);
      }
      _ensureChatTitles(chatIds);
      _completeNewChatRequest();
    }
  }

  void _handleFoundMessages(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null) {
      return;
    }

    if (extra.startsWith('searchMessages_')) {
      final requestId = int.tryParse(extra.substring('searchMessages_'.length));
      if (requestId != _globalRequestId) {
        return;
      }
      _applyGlobalMessages(update, append: false);
      _completeGlobalRequest();
      return;
    }

    if (extra.startsWith('searchMessagesMore_')) {
      final requestId =
          int.tryParse(extra.substring('searchMessagesMore_'.length));
      if (requestId != _globalRequestId) {
        return;
      }
      _applyGlobalMessages(update, append: true);
      _globalIsLoadingMore = false;
      notifyListeners();
    }
  }

  void _applyGlobalMessages(Map<String, dynamic> update, {required bool append}) {
    final hits = TdlibSearchParser.parseFoundMessages(update);
    _globalMessagesOffset = TdlibSearchParser.parseFoundMessagesNextOffset(update);
    _globalHasMoreMessages = _globalMessagesOffset.isNotEmpty;

    final enriched = hits.map((hit) {
      final title = _chatTitles[hit.chatId];
      if (title == null) {
        _client.send({
          '@type': 'getChat',
          'chat_id': hit.chatId,
          '@extra': 'searchTitle_${hit.chatId}',
        });
      }
      return hit.copyWith(chatTitle: title);
    }).toList();

    if (append) {
      _globalMessages = [..._globalMessages, ...enriched];
    } else {
      _globalMessages = enriched;
    }
  }

  void _handleFoundChatMessages(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null ||
        (!extra.startsWith('chatSearch_') &&
            !extra.startsWith('chatSearchMore_'))) {
      return;
    }

    final chatId = _chatSearchChatId;
    if (chatId == null) {
      return;
    }

    final append = extra.startsWith('chatSearchMore_');
    final title = _chatTitles[chatId];
    final hits = TdlibSearchParser.parseFoundChatMessages(
      update,
      chatId: chatId,
      chatTitle: title,
    );
    _chatSearchNextFromMessageId =
        TdlibSearchParser.parseFoundChatMessagesNextFromId(update);
    final total = TdlibSearchParser.parseTotalCount(update);
    final hasMore = _chatSearchNextFromMessageId != 0;

    _chatSearchState = _chatSearchState.copyWith(
      results: append ? [..._chatSearchState.results, ...hits] : hits,
      isLoading: false,
      isLoadingMore: false,
      hasMore: hasMore,
      totalCount: total,
    );
    notifyListeners();
  }

  void _handleChat(Map<String, dynamic> update) {
    final chatId = update['id'] as int?;
    final title = update['title'] as String?;
    if (chatId == null || title == null) {
      return;
    }

    _chatTitles[chatId] = title;

    final extra = update['@extra'] as String?;
    if (extra?.startsWith('newChatPublic_') == true) {
      final requestId = int.tryParse(extra!.substring('newChatPublic_'.length));
      if (requestId == _newChatRequestId) {
        _newChatSearchIds = {..._newChatSearchIds, chatId}.toList();
        _newChatSearchPublicIds.add(chatId);
        _completeNewChatRequest();
      }
    }

    if (extra?.startsWith('searchPublicChat_') == true) {
      final requestId = int.tryParse(extra!.substring('searchPublicChat_'.length));
      if (requestId == _globalRequestId) {
        _publicChatIds = {..._publicChatIds, chatId}.toList();
        _newChatSearchPublicIds.add(chatId);
        _completeGlobalRequest();
      }
    }

    _refreshMessageTitles(chatId, title);
    notifyListeners();
  }

  void _handleUser(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null) {
      return;
    }

    final hit = TdlibSearchParser.parseUserHit(update);
    if (hit == null) {
      return;
    }

    if (extra.startsWith('searchUserPhone_') ||
        extra.startsWith('searchUserToken_')) {
      final prefix = extra.startsWith('searchUserPhone_')
          ? 'searchUserPhone_'
          : 'searchUserToken_';
      final requestId = int.tryParse(extra.substring(prefix.length));
      if (requestId != _globalRequestId) {
        return;
      }
      _globalUserHit = hit;
      _completeGlobalRequest();
      return;
    }

    if (extra.startsWith('newChatPhone_') || extra.startsWith('newChatToken_')) {
      final prefix =
          extra.startsWith('newChatPhone_') ? 'newChatPhone_' : 'newChatToken_';
      final requestId = int.tryParse(extra.substring(prefix.length));
      if (requestId != _newChatRequestId) {
        return;
      }
      _newChatUserHit = hit;
      _completeNewChatRequest();
    }
  }

  void _handleError(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null) {
      return;
    }

    final message = update['message'] as String? ?? 'Ошибка поиска';

    if (_isGlobalExtra(extra)) {
      final requestId = _globalRequestIdFromExtra(extra);
      if (requestId != _globalRequestId) {
        return;
      }
      _globalError = message;
      if (extra.startsWith('searchMessagesMore_')) {
        _globalIsLoadingMore = false;
      } else {
        _completeGlobalRequest(forceFinish: true);
      }
      notifyListeners();
      return;
    }

    if (_isNewChatExtra(extra)) {
      final requestId = _newChatRequestIdFromExtra(extra);
      if (requestId != _newChatRequestId) {
        return;
      }
      _completeNewChatRequest();
      return;
    }

    if (extra.startsWith('chatSearch_') || extra.startsWith('chatSearchMore_')) {
      _chatSearchState = _chatSearchState.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: message,
      );
      notifyListeners();
    }
  }

  void _ensureChatTitles(List<int> chatIds) {
    for (final chatId in chatIds) {
      if (_chatTitles.containsKey(chatId)) {
        continue;
      }
      _client.send({
        '@type': 'getChat',
        'chat_id': chatId,
        '@extra': 'searchTitle_$chatId',
      });
    }
  }

  void _refreshMessageTitles(int chatId, String title) {
    _globalMessages = _globalMessages
        .map(
          (hit) => hit.chatId == chatId ? hit.copyWith(chatTitle: title) : hit,
        )
        .toList();

    if (_chatSearchChatId == chatId) {
      _chatSearchState = _chatSearchState.copyWith(
        results: _chatSearchState.results
            .map((hit) => hit.copyWith(chatTitle: title))
            .toList(),
      );
    }
  }

  void _completeGlobalRequest({bool forceFinish = false}) {
    if (!forceFinish) {
      _pendingGlobalRequests = (_pendingGlobalRequests - 1).clamp(0, 20);
      if (_pendingGlobalRequests > 0) {
        return;
      }
    }
    _globalIsLoading = false;
    notifyListeners();
  }

  void _completeNewChatRequest() {
    _pendingNewChatRequests = (_pendingNewChatRequests - 1).clamp(0, 20);
    if (_pendingNewChatRequests > 0) {
      return;
    }
    _newChatIsLoading = false;
    notifyListeners();
  }

  bool _isGlobalExtra(String extra) {
    return extra.startsWith('searchChats_') ||
        extra.startsWith('searchMessages_') ||
        extra.startsWith('searchMessagesMore_') ||
        extra.startsWith('searchPublicChats') ||
        extra.startsWith('searchPublicChat_') ||
        extra.startsWith('searchUserPhone_') ||
        extra.startsWith('searchUserToken_');
  }

  bool _isNewChatExtra(String extra) {
    return extra.startsWith('newChatSearch') ||
        extra.startsWith('newChatPublic') ||
        extra.startsWith('newChatPhone_') ||
        extra.startsWith('newChatToken_');
  }

  int? _globalRequestIdFromExtra(String extra) {
    for (final prefix in [
      'searchChats_',
      'searchMessagesMore_',
      'searchMessages_',
      'searchPublicChatsChannel_',
      'searchPublicChatsBot_',
      'searchPublicChat_',
      'searchUserPhone_',
      'searchUserToken_',
    ]) {
      if (extra.startsWith(prefix)) {
        return int.tryParse(extra.substring(prefix.length));
      }
    }
    return null;
  }

  int? _newChatRequestIdFromExtra(String extra) {
    for (final prefix in [
      'newChatSearchLocal_',
      'newChatSearch_',
      'newChatPublicChatsChannel_',
      'newChatPublicChatsBot_',
      'newChatPublic_',
      'newChatPhone_',
      'newChatToken_',
    ]) {
      if (extra.startsWith(prefix)) {
        return int.tryParse(extra.substring(prefix.length));
      }
    }
    return null;
  }
}
