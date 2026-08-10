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

  final List<ChatSummary> _chats = [];
  final List<ChatMessage> _messages = [];

  int? _activeChatId;
  String? _typingStatus;
  bool _isLoadingMessages = false;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  List<ChatSummary> get chats => List.unmodifiable(_chats);
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  int? get activeChatId => _activeChatId;
  String? get typingStatus => _typingStatus;
  bool get isLoadingMessages => _isLoadingMessages;

  ChatSummary? get activeChat {
    if (_activeChatId == null) {
      return null;
    }
    final index = _chats.indexWhere((chat) => chat.id == _activeChatId);
    return index >= 0 ? _chats[index] : null;
  }

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
  }

  void loadChats() {
    _client.send({
      '@type': 'getChats',
      'chat_list': {'@type': 'chatListMain'},
      'limit': 100,
    });
  }

  void openChat(int chatId) {
    _activeChatId = chatId;
    _messages.clear();
    _typingStatus = null;
    _isLoadingMessages = true;
    notifyListeners();

    _client.send({'@type': 'openChat', 'chat_id': chatId});
    _client.send({
      '@type': 'getChatHistory',
      'chat_id': chatId,
      'from_message_id': 0,
      'offset': 0,
      'limit': 50,
      'only_local': false,
    });
    _client.send({
      '@type': 'viewMessages',
      'chat_id': chatId,
      'message_ids': [],
      'force_read': true,
    });
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
      case 'chats':
        _handleChats(update);
      case 'chat':
        _upsertChat(TdlibChatParser.parseChat(update));
      case 'updateNewChat':
        _upsertChat(
          TdlibChatParser.parseChat(update['chat'] as Map<String, dynamic>),
        );
      case 'updateChatLastMessage':
        _handleChatLastMessage(update);
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
    }
  }

  void _handleChats(Map<String, dynamic> update) {
    final chatIds = (update['chat_ids'] as List<dynamic>? ?? []).cast<int>();
    for (final chatId in chatIds) {
      _client.send({'@type': 'getChat', 'chat_id': chatId});
    }
  }

  void _upsertChat(ChatSummary? summary) {
    if (summary == null) {
      return;
    }

    final index = _chats.indexWhere((chat) => chat.id == summary.id);
    if (index >= 0) {
      _chats[index] = _chats[index].copyWith(
        title: summary.title,
        lastMessage: summary.lastMessage ?? _chats[index].lastMessage,
        lastMessageDate: summary.lastMessageDate ?? _chats[index].lastMessageDate,
        unreadCount: summary.unreadCount,
      );
    } else {
      _chats.add(summary);
    }
    _sortChats();
    notifyListeners();
  }

  void _handleChatLastMessage(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    final lastMessage = update['last_message'] as Map<String, dynamic>?;
    if (chatId == null || lastMessage == null) {
      return;
    }

    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index < 0) {
      return;
    }

    final content = lastMessage['content'] as Map<String, dynamic>? ?? {};
    final dateSeconds = lastMessage['date'] as int? ?? 0;
    _chats[index] = _chats[index].copyWith(
      lastMessage: MessageContent.fromTdlib(content).preview,
      lastMessageDate: DateTime.fromMillisecondsSinceEpoch(dateSeconds * 1000),
    );
    _sortChats();
    notifyListeners();
  }

  void _handleMessages(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    if (chatId != _activeChatId) {
      return;
    }

    final rawMessages = update['messages'] as List<dynamic>? ?? [];
    _messages
      ..clear()
      ..addAll(
        rawMessages
            .whereType<Map<String, dynamic>>()
            .map(ChatMessage.fromTdlib)
            .toList()
            .reversed,
      );
    _isLoadingMessages = false;
    _requestMediaDownloads();
    notifyListeners();
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
      final chatTitle = _chats
              .where((chat) => chat.id == message.chatId)
              .map((chat) => chat.title)
              .firstOrNull ??
          'Новое сообщение';
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

    var changed = false;
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
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
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
    final index = _chats.indexWhere((chat) => chat.id == message.chatId);
    if (index < 0) {
      _client.send({'@type': 'getChat', 'chat_id': message.chatId});
      return;
    }

    _chats[index] = _chats[index].copyWith(
      lastMessage: message.content.preview,
      lastMessageDate: message.date,
      unreadCount: message.chatId == _activeChatId
          ? 0
          : _chats[index].unreadCount + 1,
    );
    _sortChats();
    notifyListeners();
  }

  void _sortChats() {
    _chats.sort((a, b) {
      final aDate = a.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
  }

  void _requestMediaDownloads() {
    for (final message in _messages) {
      _requestDownloadForMessage(message);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}
