import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/chat_models.dart';
import '../notifications/notification_service.dart';
import '../tdlib/tdlib_client.dart';
import 'tdlib_chat_parser.dart';

/// Управление списком чатов и активной перепиской.
class ChatManager extends ChangeNotifier {
  ChatManager({
    required TdlibClient client,
    NotificationService? notificationService,
  })  : _client = client,
        _notifications = notificationService ?? NotificationService();

  final TdlibClient _client;
  final NotificationService _notifications;

  final Map<int, ChatSummary> _chatsById = {};
  final Map<int, bool> _botUsers = {};
  final List<ChatMessage> _messages = [];
  final List<ChatFolderTab> _chatFolders = [];

  ChatListKey _activeChatList = const ChatListMain();
  int? _myUserId;
  int? _activeChatId;
  String? _typingStatus;
  bool _isLoadingMessages = false;
  String? _messagesError;
  Timer? _messagesLoadTimeout;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  List<ChatSummary> get chats => List.unmodifiable(_visibleChats);
  List<ChatFolderTab> get chatFolders => List.unmodifiable(_chatFolders);
  ChatListKey get activeChatList => _activeChatList;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  int? get activeChatId => _activeChatId;
  String? get typingStatus => _typingStatus;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get messagesError => _messagesError;
  bool get isArchiveList => _activeChatList is ChatListArchive;

  List<ChatSummary> get _visibleChats {
    final visible = _chatsById.values
        .where((chat) => chat.isInList(_activeChatList))
        .toList()
      ..sort((a, b) => ChatSummary.compareInList(a, b, _activeChatList));
    return visible;
  }

  ChatSummary? get activeChat {
    if (_activeChatId == null) {
      return null;
    }
    return _chatsById[_activeChatId];
  }

  ChatSummary? chatById(int chatId) => _chatsById[chatId];

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
    _client.send({'@type': 'getMe'});
  }

  void loadChats({ChatListKey? list, int limit = 100}) {
    final chatList = list ?? _activeChatList;
    _client.send({
      '@type': 'loadChats',
      'chat_list': chatList.toTdlib(),
      'limit': limit,
    });
  }

  void switchChatList(ChatListKey list) {
    if (_activeChatList.storageId == list.storageId) {
      return;
    }
    _activeChatList = list;
    notifyListeners();
    loadChats(list: list);
  }

  void pinChat(int chatId) {
    _client.send({
      '@type': 'toggleChatIsPinned',
      'chat_list': _activeChatList.toTdlib(),
      'chat_id': chatId,
      'is_pinned': true,
    });
  }

  void unpinChat(int chatId) {
    _client.send({
      '@type': 'toggleChatIsPinned',
      'chat_list': _activeChatList.toTdlib(),
      'chat_id': chatId,
      'is_pinned': false,
    });
  }

  void archiveChat(int chatId) {
    _client.send({
      '@type': 'addChatToList',
      'chat_id': chatId,
      'chat_list': const ChatListArchive().toTdlib(),
    });
  }

  void unarchiveChat(int chatId) {
    _client.send({
      '@type': 'addChatToList',
      'chat_id': chatId,
      'chat_list': const ChatListMain().toTdlib(),
    });
  }

  void openChat(int chatId) {
    _activeChatId = chatId;
    _messages.clear();
    _typingStatus = null;
    _messagesError = null;
    _isLoadingMessages = true;
    _startMessagesLoadTimeout(chatId);
    notifyListeners();

    _client.send({
      '@type': 'openChat',
      'chat_id': chatId,
      '@extra': 'openChat_$chatId',
    });
    _requestChatHistory(chatId, onlyLocal: true);
    _requestChatHistory(chatId, onlyLocal: false);
  }

  void closeChat() {
    if (_activeChatId != null) {
      _client.send({'@type': 'closeChat', 'chat_id': _activeChatId});
    }
    _activeChatId = null;
    _messages.clear();
    _typingStatus = null;
    notifyListeners();
  }

  void sendText(String text) {
    final chatId = _activeChatId;
    final trimmed = text.trim();
    if (chatId == null || trimmed.isEmpty) {
      return;
    }

    _client.send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {
          '@type': 'formattedText',
          'text': trimmed,
          'entities': [],
        },
      },
    });
  }

  Future<void> sendFile(String path) async {
    final chatId = _activeChatId;
    if (chatId == null) {
      return;
    }

    _client.send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageDocument',
        'document': {
          '@type': 'inputFileLocal',
          'path': path,
        },
      },
    });
  }

  void sendTypingAction() {
    final chatId = _activeChatId;
    if (chatId == null) {
      return;
    }

    _client.send({
      '@type': 'sendChatAction',
      'chat_id': chatId,
      'action': {'@type': 'chatActionTyping'},
    });
  }

  void _handleUpdate(Map<String, dynamic> update) {
    final type = update['@type'];

    switch (type) {
      case 'user':
        _handleUser(update);
      case 'updateUser':
        _handleUser(update['user'] as Map<String, dynamic>);
      case 'updateChatFolders':
        _handleChatFolders(update);
      case 'updateNewChat':
        _upsertChat(
          TdlibChatParser.parseChat(
            update['chat'] as Map<String, dynamic>,
            myUserId: _myUserId,
            botUsers: _botUsers,
          ),
        );
      case 'chat':
        _upsertChat(
          TdlibChatParser.parseChat(
            update,
            myUserId: _myUserId,
            botUsers: _botUsers,
          ),
        );
      case 'updateChatLastMessage':
        _handleChatLastMessage(update);
      case 'updateChatPosition':
        _handleUpdateChatPosition(update);
      case 'updateChatDraftMessage':
        _handleUpdateChatDraftMessage(update);
      case 'updateChatNotificationSettings':
        _handleUpdateChatNotificationSettings(update);
      case 'updateChatReadInbox':
        _handleUpdateChatReadInbox(update);
      case 'messages':
        _handleMessages(update);
      case 'message':
        _handleSingleMessage(update);
      case 'updateNewMessage':
        _handleNewMessage(update);
      case 'updateMessageSendSucceeded':
        _handleSendSucceeded(update);
      case 'updateUserChatAction':
        _handleTyping(update);
      case 'updateFile':
        _handleFileUpdate(update);
      case 'updateChatPhoto':
        _handleChatPhoto(update);
      case 'ok':
        _handleOk(update);
      case 'error':
        _handleError(update);
    }
  }

  void _handleUser(Map<String, dynamic> user) {
    final userId = user['id'] as int?;
    if (userId == null) {
      return;
    }

    if (user['@type'] == 'user' && (user['is_self'] as bool? ?? false)) {
      _myUserId = userId;
    }

    final isBot = TdlibChatParser.isBotUser(user);
    final previous = _botUsers[userId];
    if (previous != isBot) {
      _botUsers[userId] = isBot;
      _refreshPrivateChatKinds(userId);
    }
  }

  void _refreshPrivateChatKinds(int userId) {
    var changed = false;
    for (final entry in _chatsById.entries) {
      final chat = entry.value;
      if (chat.privateUserId != userId) {
        continue;
      }
      final kind = TdlibChatParser.resolvePrivateChatKind(
        userId: userId,
        myUserId: _myUserId,
        botUsers: _botUsers,
      );
      if (chat.kind != kind) {
        _chatsById[entry.key] = chat.copyWith(kind: kind);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void _handleChatFolders(Map<String, dynamic> update) {
    _chatFolders
      ..clear()
      ..addAll(TdlibChatParser.parseChatFolders(update));
    notifyListeners();
  }

  void _handleOk(Map<String, dynamic> update) {
    // getChatHistory вызывается сразу в openChat; ok дублировать не нужно.
  }

  void _handleError(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null) {
      return;
    }

    final message = (update['message'] as String? ?? '').toLowerCase();

    if (extra.startsWith('getChatHistory_') || extra.startsWith('getChatHistoryLocal_')) {
      final chatId = _chatIdFromExtra(extra, 'getChatHistoryLocal_') ??
          _chatIdFromExtra(extra, 'getChatHistory_');
      if (chatId == null || chatId != _activeChatId) {
        return;
      }

      if (message.contains('chat') && message.contains('open')) {
        _client.send({'@type': 'openChat', 'chat_id': chatId});
        _requestChatHistory(chatId, onlyLocal: true);
        _requestChatHistory(chatId, onlyLocal: false);
        return;
      }

      _messagesLoadTimeout?.cancel();
      _isLoadingMessages = false;
      _messagesError = update['message'] as String? ?? 'Не удалось загрузить сообщения';
      notifyListeners();
      return;
    }

    if (extra.startsWith('openChat_')) {
      final chatId = _chatIdFromExtra(extra, 'openChat_');
      if (chatId == null || chatId != _activeChatId) {
        return;
      }

      _messagesLoadTimeout?.cancel();
      _isLoadingMessages = false;
      _messagesError = update['message'] as String? ?? 'Не удалось открыть чат';
      notifyListeners();
    }
  }

  int? _chatIdFromExtra(String? extra, String prefix) {
    if (extra == null || !extra.startsWith(prefix)) {
      return null;
    }
    return int.tryParse(extra.substring(prefix.length));
  }

  void _requestChatHistory(int chatId, {required bool onlyLocal}) {
    _client.send({
      '@type': 'getChatHistory',
      'chat_id': chatId,
      'from_message_id': 0,
      'offset': 0,
      'limit': 50,
      'only_local': onlyLocal,
      '@extra': onlyLocal
          ? 'getChatHistoryLocal_$chatId'
          : 'getChatHistory_$chatId',
    });
  }

  void _startMessagesLoadTimeout(int chatId) {
    _messagesLoadTimeout?.cancel();
    _messagesLoadTimeout = Timer(const Duration(seconds: 30), () {
      if (_activeChatId != chatId || !_isLoadingMessages) {
        return;
      }
      _isLoadingMessages = false;
      _messagesError = 'Таймаут загрузки сообщений';
      notifyListeners();
    });
  }

  void _handleChatPhoto(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    final photo = update['photo'] as Map<String, dynamic>?;
    if (chatId == null || photo == null) {
      return;
    }

    final chat = _chatsById[chatId];
    if (chat == null) {
      return;
    }

    final avatar = TdlibChatParser.parseAvatar(photo);
    _chatsById[chatId] = chat.copyWith(
      avatarFileId: avatar.fileId,
      avatarLocalPath: avatar.localPath,
    );
    _requestAvatarDownload(avatar.fileId, avatar.localPath);
    notifyListeners();
  }

  void _upsertChat(ChatSummary? summary) {
    if (summary == null) {
      return;
    }

    final existing = _chatsById[summary.id];
    if (existing != null) {
      _chatsById[summary.id] = existing.copyWith(
        title: summary.title,
        lastMessage: summary.lastMessage ?? existing.lastMessage,
        lastMessageDate: summary.lastMessageDate ?? existing.lastMessageDate,
        unreadCount: summary.unreadCount,
        avatarFileId: summary.avatarFileId ?? existing.avatarFileId,
        avatarLocalPath: summary.avatarLocalPath ?? existing.avatarLocalPath,
        kind: summary.kind,
        positions: summary.positions.isNotEmpty ? summary.positions : existing.positions,
        isMuted: summary.isMuted,
        draftPreview: summary.draftPreview ?? existing.draftPreview,
        privateUserId: summary.privateUserId ?? existing.privateUserId,
      );
    } else {
      _chatsById[summary.id] = summary;
    }

    final chat = _chatsById[summary.id]!;
    _requestAvatarDownload(chat.avatarFileId, chat.avatarLocalPath);
    _requestUserForPrivateChat(chat);
    notifyListeners();
  }

  void _requestUserForPrivateChat(ChatSummary chat) {
    final userId = chat.privateUserId;
    if (userId == null || _botUsers.containsKey(userId)) {
      return;
    }
    _client.send({'@type': 'getUser', 'user_id': userId});
  }

  void _handleChatLastMessage(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    final lastMessage = update['last_message'] as Map<String, dynamic>?;
    if (chatId == null) {
      return;
    }

    final chat = _chatsById[chatId];
    if (chat == null) {
      _client.send({'@type': 'getChat', 'chat_id': chatId});
      return;
    }

    String? preview = chat.lastMessage;
    DateTime? date = chat.lastMessageDate;
    if (lastMessage != null) {
      final content = lastMessage['content'] as Map<String, dynamic>? ?? {};
      preview = MessageContent.fromTdlib(content).preview;
      final dateSeconds = lastMessage['date'] as int? ?? 0;
      date = DateTime.fromMillisecondsSinceEpoch(dateSeconds * 1000);
    }

    final positions = TdlibChatParser.parsePositions(update['positions'] as List<dynamic>?);
    _chatsById[chatId] = chat.copyWith(
      lastMessage: preview,
      lastMessageDate: date,
      positions: positions.isNotEmpty ? positions : chat.positions,
    );
    notifyListeners();
  }

  void _handleUpdateChatPosition(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    final positionRaw = update['position'] as Map<String, dynamic>?;
    if (chatId == null || positionRaw == null) {
      return;
    }

    final position = ChatPositionInfo.fromTdlib(positionRaw);
    final chat = _chatsById[chatId];
    if (chat == null) {
      _client.send({'@type': 'getChat', 'chat_id': chatId});
      return;
    }

    _chatsById[chatId] = chat.copyWith(
      positions: _mergePosition(chat.positions, position),
    );
    notifyListeners();
  }

  void _handleUpdateChatDraftMessage(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    if (chatId == null) {
      return;
    }

    final chat = _chatsById[chatId];
    if (chat == null) {
      _client.send({'@type': 'getChat', 'chat_id': chatId});
      return;
    }

    final draft = update['draft_message'] as Map<String, dynamic>?;
    final draftPreview = TdlibChatParser.parseDraftPreview(draft);
    final positions = TdlibChatParser.parsePositions(update['positions'] as List<dynamic>?);

    _chatsById[chatId] = chat.copyWith(
      draftPreview: draftPreview,
      clearDraftPreview: draftPreview == null,
      positions: positions.isNotEmpty ? positions : chat.positions,
    );
    notifyListeners();
  }

  void _handleUpdateChatNotificationSettings(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    final settings = update['notification_settings'] as Map<String, dynamic>?;
    if (chatId == null || settings == null) {
      return;
    }

    final chat = _chatsById[chatId];
    if (chat == null) {
      return;
    }

    _chatsById[chatId] = chat.copyWith(
      isMuted: TdlibChatParser.isChatMuted(settings),
    );
    notifyListeners();
  }

  void _handleUpdateChatReadInbox(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    if (chatId == null) {
      return;
    }

    final chat = _chatsById[chatId];
    if (chat == null) {
      return;
    }

    _chatsById[chatId] = chat.copyWith(
      unreadCount: update['unread_count'] as int? ?? chat.unreadCount,
    );
    notifyListeners();
  }

  List<ChatPositionInfo> _mergePosition(
    List<ChatPositionInfo> existing,
    ChatPositionInfo update,
  ) {
    final listId = update.list.storageId;
    final filtered = existing.where((item) => item.list.storageId != listId).toList();
    if (update.order != 0) {
      filtered.add(update);
    }
    return filtered;
  }

  void _handleMessages(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    final isLocal = extra?.startsWith('getChatHistoryLocal_') ?? false;
    final chatId = update['chat_id'] as int? ??
        _chatIdFromExtra(extra, 'getChatHistoryLocal_') ??
        _chatIdFromExtra(extra, 'getChatHistory_');
    if (chatId == null || chatId != _activeChatId) {
      return;
    }

    final rawMessages = update['messages'] as List<dynamic>? ?? [];
    final parsed = rawMessages
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromTdlib)
        .toList()
        .reversed
        .toList();

    if (parsed.isNotEmpty) {
      _messages
        ..clear()
        ..addAll(parsed);
      _requestMediaDownloads();
    }

    if (isLocal) {
      // Кэш показан сразу — не ждём сеть (прокси может быть недоступен).
      _isLoadingMessages = false;
      _messagesError = null;
      notifyListeners();
      return;
    }

    _messagesLoadTimeout?.cancel();
    _messagesError = null;
    _isLoadingMessages = false;
    if (parsed.isNotEmpty) {
      _markMessagesRead(chatId, parsed);
    }
    notifyListeners();
  }

  void _markMessagesRead(int chatId, List<ChatMessage> messages) {
    final ids = messages.map((message) => message.id).where((id) => id > 0).toList();
    if (ids.isEmpty) {
      return;
    }

    _client.send({
      '@type': 'viewMessages',
      'chat_id': chatId,
      'message_ids': ids,
      'source': {'@type': 'messageSourceChatHistory'},
      'force_read': true,
      '@extra': 'viewMessages_$chatId',
    });
  }

  void _handleSingleMessage(Map<String, dynamic> update) {
    final message = TdlibChatParser.parseMessage(update);
    if (message == null) {
      return;
    }
    _insertMessage(message);
  }

  void _handleNewMessage(Map<String, dynamic> update) {
    final message = TdlibChatParser.parseMessage(
      update['message'] as Map<String, dynamic>,
    );
    if (message == null) {
      return;
    }

    _insertMessage(message);
    _updateChatPreview(message);

    if (message.chatId != _activeChatId) {
      final chatTitle = _chatsById[message.chatId]?.title ?? 'Новое сообщение';
      _notifications.showMessageNotification(
        title: chatTitle,
        body: message.content.preview,
      );
    }
  }

  void _handleSendSucceeded(Map<String, dynamic> update) {
    final message = TdlibChatParser.parseMessage(
      update['message'] as Map<String, dynamic>,
    );
    if (message == null) {
      return;
    }
    _replaceMessage(message);
  }

  void _handleTyping(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    if (chatId != _activeChatId) {
      return;
    }

    _typingStatus = TdlibChatParser.parseTypingAction(update);
    notifyListeners();
  }

  void _handleFileUpdate(Map<String, dynamic> update) {
    final file = update['file'] as Map<String, dynamic>?;
    if (file == null) {
      return;
    }

    final local = file['local'] as Map<String, dynamic>?;
    final localPath = local?['path'] as String?;
    final isDownloadingCompleted = local?['is_downloading_completed'] as bool? ?? false;
    final fileId = file['id'] as int?;
    if (localPath == null || fileId == null || !isDownloadingCompleted) {
      return;
    }

    var messagesChanged = false;
    for (var i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      if (message.mediaFileId == fileId) {
        _messages[i] = message.copyWith(
          localFilePath: localPath,
          content: MessageContent(
            kind: message.content.kind,
            preview: message.content.preview,
            caption: message.content.caption,
            localPath: localPath,
            fileName: message.content.fileName,
          ),
        );
        messagesChanged = true;
      }
    }

    var chatsChanged = false;
    for (final entry in _chatsById.entries) {
      if (entry.value.avatarFileId == fileId) {
        _chatsById[entry.key] = entry.value.copyWith(avatarLocalPath: localPath);
        chatsChanged = true;
      }
    }

    if (messagesChanged || chatsChanged) {
      notifyListeners();
    }
  }

  void _requestAvatarDownload(int? fileId, String? localPath) {
    if (fileId == null) {
      return;
    }
    if (localPath != null && localPath.isNotEmpty) {
      return;
    }

    _client.send({
      '@type': 'downloadFile',
      'file_id': fileId,
      'priority': 16,
      'offset': 0,
      'limit': 0,
      'synchronous': false,
    });
  }

  void _requestDownloadForMessage(ChatMessage message) {
    if (message.content.kind == MessageKind.text ||
        message.localFilePath != null ||
        message.mediaFileId == null) {
      return;
    }

    _client.send({
      '@type': 'downloadFile',
      'file_id': message.mediaFileId,
      'priority': 16,
      'offset': 0,
      'limit': 0,
      'synchronous': false,
    });
  }

  void _insertMessage(ChatMessage message) {
    if (message.chatId != _activeChatId) {
      return;
    }

    final index = _messages.indexWhere((item) => item.id == message.id);
    if (index >= 0) {
      _messages[index] = message;
    } else {
      _messages.add(message);
      _messages.sort((a, b) => a.date.compareTo(b.date));
    }
    _isLoadingMessages = false;
    _requestDownloadForMessage(message);
    notifyListeners();
  }

  void _replaceMessage(ChatMessage message) {
    if (message.chatId != _activeChatId) {
      return;
    }

    final pendingIndex = _messages.indexWhere(
      (item) => item.isOutgoing && item.id > message.id,
    );
    if (pendingIndex >= 0) {
      _messages[pendingIndex] = message;
    } else {
      _insertMessage(message);
      return;
    }
    notifyListeners();
  }

  void _updateChatPreview(ChatMessage message) {
    final chat = _chatsById[message.chatId];
    if (chat == null) {
      _client.send({'@type': 'getChat', 'chat_id': message.chatId});
      return;
    }

    _chatsById[message.chatId] = chat.copyWith(
      lastMessage: message.content.preview,
      lastMessageDate: message.date,
      unreadCount: message.chatId == _activeChatId ? 0 : chat.unreadCount + 1,
    );
    notifyListeners();
  }

  void _requestMediaDownloads() {
    for (final message in _messages) {
      _requestDownloadForMessage(message);
    }
  }

  @override
  void dispose() {
    _messagesLoadTimeout?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
