import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/bot_models.dart';
import '../../models/message_enrichment.dart';
import '../tdlib/tdlib_client.dart';
import '../tdlib/tdlib_json.dart';
import 'tdlib_bot_parser.dart';

/// Inline-кнопки, callback, inline-режим и Web Apps.
class BotManager extends ChangeNotifier {
  BotManager({required TdlibClient client}) : _client = client;

  final TdlibClient _client;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  final Map<String, int> _usernameToUserId = {};
  final Map<int, BotInfoModel> _botInfoByUserId = {};

  InlineQueryState _inlineQueryState = const InlineQueryState();
  CallbackQueryAnswerModel? _lastCallbackAnswer;
  var _isCallbackLoading = false;
  var _pendingInlineChatId = 0;
  String? _lastError;
  int _inlineRequestId = 0;
  int? _pendingWebAppLaunchId;
  String? _pendingWebAppUrl;

  InlineQueryState get inlineQueryState => _inlineQueryState;
  CallbackQueryAnswerModel? get lastCallbackAnswer => _lastCallbackAnswer;
  bool get isCallbackLoading => _isCallbackLoading;
  String? get lastError => _lastError;
  int? get pendingWebAppLaunchId => _pendingWebAppLaunchId;
  String? get pendingWebAppUrl => _pendingWebAppUrl;

  void clearLastCallbackAnswer() {
    _lastCallbackAnswer = null;
  }

  void clearPendingWebApp() {
    _pendingWebAppLaunchId = null;
    _pendingWebAppUrl = null;
  }

  BotInfoModel? botInfoFor(int userId) => _botInfoByUserId[userId];

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void registerUsername(String username, int userId) {
    if (username.isEmpty) {
      return;
    }
    _usernameToUserId[username.toLowerCase()] = userId;
  }

  void cacheBotInfo(int userId, BotInfoModel info) {
    if (info.commands.isEmpty &&
        info.description.isEmpty &&
        info.shortDescription.isEmpty) {
      return;
    }
    _botInfoByUserId[userId] = info;
    notifyListeners();
  }

  List<BotCommandModel> commandsFor(int botUserId) {
    return _botInfoByUserId[botUserId]?.commands ?? const [];
  }

  void handleComposerText({
    required String text,
    required int chatId,
  }) {
    final parsed = TdlibBotParser.parseInlineComposerQuery(text);
    if (parsed == null) {
      if (_inlineQueryState.isActive) {
        _inlineQueryState = const InlineQueryState();
        notifyListeners();
      }
      return;
    }

    final botUserId = TdlibBotParser.resolveBotUserId(
      username: parsed.username,
      usernameToUserId: _usernameToUserId,
    );
    if (botUserId == null) {
      _resolveBotUsername(parsed.username, chatId, parsed.query);
      return;
    }

    _performInlineQuery(
      botUserId: botUserId,
      botUsername: parsed.username,
      chatId: chatId,
      query: parsed.query,
    );
  }

  void _resolveBotUsername(String username, int chatId, String query) {
    _pendingInlineChatId = chatId;
    _inlineQueryState = InlineQueryState(
      botUsername: username,
      query: query,
      isLoading: true,
    );
    notifyListeners();
    _client.send({
      '@type': 'searchPublicChat',
      'username': username,
      '@extra': 'bot_inline_resolve_$username',
    });
  }

  void _performInlineQuery({
    required int botUserId,
    required String botUsername,
    required int chatId,
    required String query,
  }) {
    final requestId = ++_inlineRequestId;
    _inlineQueryState = InlineQueryState(
      botUserId: botUserId,
      botUsername: botUsername,
      query: query,
      isLoading: true,
    );
    notifyListeners();
    _client.send({
      '@type': 'getInlineQueryResults',
      'bot_user_id': botUserId,
      'chat_id': chatId,
      'user_location': null,
      'query': query,
      'offset': '',
      '@extra': 'bot_inline_results_${requestId}_$chatId',
    });
  }

  void sendInlineResult({
    required int chatId,
    required int queryId,
    required String resultId,
  }) {
    _client.send({
      '@type': 'sendInlineQueryResultMessage',
      'chat_id': chatId,
      'topic_id': null,
      'reply_to': null,
      'options': null,
      'query_id': queryId,
      'result_id': resultId,
      'hide_via_bot': false,
      '@extra': 'bot_inline_send_$chatId',
    });
    _inlineQueryState = const InlineQueryState();
    notifyListeners();
  }

  void clearInlineQuery() {
    _inlineQueryState = const InlineQueryState();
    notifyListeners();
  }

  void pressInlineButton({
    required int chatId,
    required int messageId,
    required InlineKeyboardButtonModel button,
    required int botUserId,
  }) {
    _isCallbackLoading = true;
    _lastError = null;
    notifyListeners();

    switch (button.kind) {
      case InlineKeyboardButtonKind.callback:
      case InlineKeyboardButtonKind.callbackWithPassword:
        _client.send({
          '@type': 'getCallbackQueryAnswer',
          'chat_id': chatId,
          'message_id': messageId,
          'payload': TdlibBotParser.callbackPayload(button.callbackData ?? ''),
          '@extra': 'bot_callback_${chatId}_$messageId',
        });
      case InlineKeyboardButtonKind.game:
        _client.send({
          '@type': 'getCallbackQueryAnswer',
          'chat_id': chatId,
          'message_id': messageId,
          'payload': TdlibBotParser.callbackGamePayload(),
          '@extra': 'bot_callback_${chatId}_$messageId',
        });
      case InlineKeyboardButtonKind.webApp:
        openWebApp(
          chatId: chatId,
          botUserId: botUserId,
          url: button.webAppUrl ?? '',
        );
        _isCallbackLoading = false;
        notifyListeners();
      case InlineKeyboardButtonKind.buy:
        _lastError = 'Покупки через inline-кнопки пока не поддерживаются';
        _isCallbackLoading = false;
        notifyListeners();
      default:
        _isCallbackLoading = false;
        notifyListeners();
    }
  }

  void openWebApp({
    required int chatId,
    required int botUserId,
    required String url,
  }) {
    if (url.isEmpty) {
      return;
    }
    _client.send({
      '@type': 'openWebApp',
      'chat_id': chatId,
      'bot_user_id': botUserId,
      'url': url,
      'topic_id': null,
      'reply_to': null,
      'parameters': {
        '@type': 'webAppOpenParameters',
        'theme': {'@type': 'themeParameters'},
        'application_name': 'RioGram',
        'mode': {'@type': 'webAppOpenModeFullSize'},
      },
      '@extra': 'bot_webapp_$chatId',
    });
  }

  void closeWebApp({required int webAppLaunchId}) {
    _client.send({
      '@type': 'closeWebApp',
      'web_app_launch_id': webAppLaunchId,
    });
  }

  void _handleUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case 'chat':
        _handleResolvedBotChat(update);
      case 'inlineQueryResults':
        _handleInlineQueryResults(update);
      case 'callbackQueryAnswer':
        _handleCallbackAnswer(update);
      case 'webAppInfo':
        _handleWebAppInfo(update);
      case 'error':
        _handleError(update);
    }
  }

  void _handleResolvedBotChat(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('bot_inline_resolve_')) {
      return;
    }
    final username = extra.substring('bot_inline_resolve_'.length);
    final type = update['type'] as Map<String, dynamic>?;
    final userId = tdInt((type?['user_id']));
    if (userId == null) {
      _inlineQueryState = InlineQueryState(
        botUsername: username,
        query: _inlineQueryState.query,
        error: 'Бот @$username не найден',
      );
      notifyListeners();
      return;
    }

    registerUsername(username, userId);
    _performInlineQuery(
      botUserId: userId,
      botUsername: username,
      chatId: _pendingInlineChatId,
      query: _inlineQueryState.query,
    );
  }

  void _handleInlineQueryResults(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('bot_inline_results_')) {
      return;
    }

    final results = TdlibBotParser.parseInlineQueryResults(update);
    final queryId = BotSettingsJson.parseInlineQueryId(update);
    _inlineQueryState = _inlineQueryState.copyWith(
      results: results,
      queryId: queryId,
      isLoading: false,
      error: results.isEmpty ? 'Нет результатов' : null,
    );
    notifyListeners();
  }

  void _handleCallbackAnswer(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('bot_callback_')) {
      return;
    }
    _lastCallbackAnswer = TdlibBotParser.parseCallbackAnswer(update);
    _isCallbackLoading = false;
    notifyListeners();
  }

  void _handleWebAppInfo(Map<String, dynamic> update) {
    if ((update['@extra'] as String?)?.startsWith('bot_webapp_') != true) {
      return;
    }
    _pendingWebAppLaunchId = tdIntOr(update['launch_id']);
    final urlObj = update['url'] as Map<String, dynamic>?;
    _pendingWebAppUrl = urlObj?['url'] as String?;
    notifyListeners();
  }

  void _handleError(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('bot_')) {
      return;
    }
    _isCallbackLoading = false;
    _lastError = update['message'] as String? ?? 'Ошибка бота';
    if (extra.startsWith('bot_inline_')) {
      _inlineQueryState = _inlineQueryState.copyWith(
        isLoading: false,
        error: _lastError,
      );
    }
    notifyListeners();
  }
}

extension InlineQueryStateCopy on InlineQueryState {
  InlineQueryState copyWith({
    int? botUserId,
    String? botUsername,
    String? query,
    List<InlineQueryResultModel>? results,
    int? queryId,
    bool? isLoading,
    String? error,
  }) {
    return InlineQueryState(
      botUserId: botUserId ?? this.botUserId,
      botUsername: botUsername ?? this.botUsername,
      query: query ?? this.query,
      results: results ?? this.results,
      queryId: queryId ?? this.queryId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
