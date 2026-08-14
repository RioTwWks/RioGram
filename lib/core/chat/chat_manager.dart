import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/audio_models.dart';
import '../../models/chat_models.dart';
import '../../models/formatted_text.dart';
import '../../models/message_enrichment.dart';
import '../media/media_cache_manager.dart';
import '../notifications/notification_service.dart';
import '../tdlib/tdlib_client.dart';
import 'formatted_text_builder.dart';
import 'tdlib_chat_parser.dart';

/// Управление списком чатов и активной перепиской.
class ChatManager extends ChangeNotifier {
  ChatManager({
    required TdlibClient client,
    NotificationService? notificationService,
    MediaCacheManager? mediaCache,
  })  : _client = client,
        _notifications = notificationService ?? NotificationService(),
        _mediaCache = mediaCache;

  final TdlibClient _client;
  final NotificationService _notifications;
  final MediaCacheManager? _mediaCache;

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

  String _searchQuery = '';
  List<int> _searchChatIds = [];
  List<SearchMessageHit> _searchMessages = [];
  bool _isSearchLoading = false;
  String? _searchError;
  Timer? _searchDebounce;
  int _searchRequestId = 0;
  int _pendingSearchRequests = 0;

  List<int> _newChatSearchIds = [];
  bool _isNewChatSearchLoading = false;
  Timer? _newChatSearchDebounce;
  int _newChatSearchRequestId = 0;

  final Map<int, FileTransferState> _fileTransfers = {};
  int _pendingNewChatSearchRequests = 0;

  MessageReplyDraft? _pendingReply;
  DateTime? _scheduledSendAt;
  MessageEditDraft? _editingMessage;
  bool _selectionMode = false;
  final Set<int> _selectedMessageIds = {};
  Timer? _typingStatusClearTimer;
  final Map<int, int> _lastReadOutboxMessageId = {};

  List<ChatSummary> get chats => List.unmodifiable(_visibleChats);
  List<ChatFolderTab> get chatFolders => List.unmodifiable(_chatFolders);
  ChatListKey get activeChatList => _activeChatList;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  int? get activeChatId => _activeChatId;
  String? get typingStatus => _typingStatus;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get messagesError => _messagesError;
  bool get isArchiveList => _activeChatList is ChatListArchive;
  String get searchQuery => _searchQuery;
  bool get isSearchActive => _searchQuery.isNotEmpty;
  bool get isSearchLoading => _isSearchLoading;
  String? get searchError => _searchError;
  List<SearchMessageHit> get searchMessageResults =>
      List.unmodifiable(_searchMessages);

  List<ChatSummary> get newChatSearchResults {
    return _newChatSearchIds
        .map((id) => _chatsById[id])
        .whereType<ChatSummary>()
        .toList();
  }

  bool get isNewChatSearchLoading => _isNewChatSearchLoading;
  MessageReplyDraft? get pendingReply => _pendingReply;
  MessageEditDraft? get editingMessage => _editingMessage;
  DateTime? get scheduledSendAt => _scheduledSendAt;
  bool get isSelectionMode => _selectionMode;
  Set<int> get selectedMessageIds => Set.unmodifiable(_selectedMessageIds);
  int get selectedMessageCount => _selectedMessageIds.length;

  /// Чаты текущего списка для клавиатурной навигации (без Saved Messages).
  List<ChatSummary> get navigableChats {
    return chats.where((chat) => chat.kind != ChatKind.savedMessages).toList();
  }

  List<ChatSummary> get searchChatResults {
    return _searchChatIds
        .map((id) => _chatsById[id])
        .whereType<ChatSummary>()
        .toList();
  }

  int? get savedMessagesChatId {
    for (final chat in _chatsById.values) {
      if (chat.kind == ChatKind.savedMessages) {
        return chat.id;
      }
    }
    return null;
  }

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

  ChatMessage? messageById(int messageId) {
    for (final message in _messages) {
      if (message.id == messageId) {
        return message;
      }
    }
    return null;
  }

  int _lastReadOutboxForActiveChat() =>
      _activeChatId == null ? 0 : (_lastReadOutboxMessageId[_activeChatId!] ?? 0);

  ChatMessage? _parseMessage(Map<String, dynamic> json) {
    return TdlibChatParser.parseMessage(
      json,
      lastReadOutboxMessageId: _lastReadOutboxForActiveChat(),
    );
  }

  void _refreshDeliveryStatuses() {
    final chatId = _activeChatId;
    if (chatId == null) {
      return;
    }
    final lastRead = _lastReadOutboxMessageId[chatId] ?? 0;
    var changed = false;
    for (var i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      if (!message.isOutgoing) {
        continue;
      }
      if (message.deliveryStatus == MessageDeliveryStatus.sending ||
          message.deliveryStatus == MessageDeliveryStatus.failed) {
        continue;
      }
      final status = message.id > 0 && message.id <= lastRead
          ? MessageDeliveryStatus.read
          : MessageDeliveryStatus.sent;
      if (status != message.deliveryStatus) {
        _messages[i] = message.copyWith(deliveryStatus: status);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  String replyPreviewFor(ChatMessage message) {
    final reply = message.replyTo;
    if (reply == null) {
      return '';
    }
    return messageById(reply.messageId)?.content.preview ?? reply.preview;
  }

  bool get canDeleteSelectedForAll {
    if (_selectedMessageIds.isEmpty) {
      return false;
    }
    for (final id in _selectedMessageIds) {
      final message = messageById(id);
      if (message == null || !message.canBeDeletedForAllUsers) {
        return false;
      }
    }
    return true;
  }

  bool get canDeleteSelectedForSelf {
    if (_selectedMessageIds.isEmpty) {
      return false;
    }
    for (final id in _selectedMessageIds) {
      final message = messageById(id);
      if (message == null || !message.canBeDeletedOnlyForSelf) {
        return false;
      }
    }
    return true;
  }

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

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    _searchDebounce?.cancel();

    if (_searchQuery.isEmpty) {
      _clearSearchResults();
      notifyListeners();
      return;
    }

    _isSearchLoading = true;
    _searchError = null;
    notifyListeners();

    _searchDebounce = Timer(const Duration(milliseconds: 350), _performSearch);
  }

  void clearSearch() {
    _searchDebounce?.cancel();
    _searchQuery = '';
    _clearSearchResults();
    notifyListeners();
  }

  void searchForNewChat(String query) {
    _newChatSearchDebounce?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      _newChatSearchIds = [];
      _isNewChatSearchLoading = false;
      _pendingNewChatSearchRequests = 0;
      notifyListeners();
      return;
    }

    _isNewChatSearchLoading = true;
    notifyListeners();

    _newChatSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      final requestId = ++_newChatSearchRequestId;
      _pendingNewChatSearchRequests = 2;

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
    });
  }

  void clearNewChatSearch() {
    _newChatSearchDebounce?.cancel();
    _newChatSearchIds = [];
    _isNewChatSearchLoading = false;
    _pendingNewChatSearchRequests = 0;
    notifyListeners();
  }

  void _clearSearchResults() {
    _searchChatIds = [];
    _searchMessages = [];
    _isSearchLoading = false;
    _searchError = null;
    _pendingSearchRequests = 0;
  }

  void _performSearch() {
    final requestId = ++_searchRequestId;
    final query = _searchQuery;
    _pendingSearchRequests = 2;
    _isSearchLoading = true;
    _searchError = null;

    _client.send({
      '@type': 'searchChats',
      'query': query,
      'limit': 20,
      '@extra': 'searchChats_$requestId',
    });
    _client.send({
      '@type': 'searchMessages',
      'query': query,
      'offset': '',
      'limit': 20,
      'min_date': 0,
      'max_date': 0,
      '@extra': 'searchMessages_$requestId',
    });
  }

  void toggleMarkedAsUnread(int chatId, {required bool isMarkedAsUnread}) {
    _client.send({
      '@type': 'toggleChatIsMarkedAsUnread',
      'chat_id': chatId,
      'is_marked_as_unread': isMarkedAsUnread,
    });
  }

  void clearChatHistory(int chatId) {
    _client.send({
      '@type': 'deleteChatHistory',
      'chat_id': chatId,
      'remove_from_chat_list': false,
      'revoke': false,
    });
  }

  void deleteChat(int chatId) {
    final chat = _chatsById[chatId];
    if (chat?.canLeave ?? false) {
      _client.send({'@type': 'leaveChat', 'chat_id': chatId});
      return;
    }

    _client.send({
      '@type': 'deleteChatHistory',
      'chat_id': chatId,
      'remove_from_chat_list': true,
      'revoke': false,
    });
  }

  void deleteChatForAll(int chatId) {
    _client.send({
      '@type': 'deleteChatHistory',
      'chat_id': chatId,
      'remove_from_chat_list': true,
      'revoke': true,
    });
  }

  void openSavedMessages() {
    final chatId = savedMessagesChatId;
    if (chatId != null) {
      openChat(chatId);
    }
  }

  void openChatAtMessage(int chatId, int messageId) {
    openChat(chatId);
    _client.send({
      '@type': 'viewMessages',
      'chat_id': chatId,
      'message_ids': [messageId],
      'source': {'@type': 'messageSourceSearch'},
      'force_read': false,
    });
  }

  void openChat(int chatId) {
    _activeChatId = chatId;
    _messages.clear();
    _typingStatus = null;
    _messagesError = null;
    _pendingReply = null;
    _scheduledSendAt = null;
    _editingMessage = null;
    _exitSelectionMode();
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
    _pendingReply = null;
    _scheduledSendAt = null;
    _editingMessage = null;
    _exitSelectionMode();
    notifyListeners();
  }

  void setReplyToMessage(ChatMessage message) {
    _pendingReply = MessageReplyDraft(
      messageId: message.id,
      preview: message.content.preview,
      authorName: message.senderName ?? (message.isOutgoing ? 'Вы' : activeChat?.title),
    );
    notifyListeners();
  }

  void clearReply() {
    if (_pendingReply == null) {
      return;
    }
    _pendingReply = null;
    notifyListeners();
  }

  void startEditingMessage(ChatMessage message) {
    if (!message.canEditText && !message.canEditCaption) {
      return;
    }
    final text = message.editableComposerText ?? '';
    _editingMessage = MessageEditDraft(
      messageId: message.id,
      initialText: text,
      isCaption: message.canEditCaption && !message.canEditText,
    );
    _pendingReply = null;
    _scheduledSendAt = null;
    notifyListeners();
  }

  void cancelEditing() {
    if (_editingMessage == null) {
      return;
    }
    _editingMessage = null;
    notifyListeners();
  }

  void saveEdit(String raw) {
    final chatId = _activeChatId;
    final draft = _editingMessage;
    if (chatId == null || draft == null) {
      return;
    }

    final formatted = FormattedTextBuilder.buildFromComposer(raw);
    if (formatted.text.trim().isEmpty) {
      return;
    }

    if (draft.isCaption) {
      _client.send({
        '@type': 'editMessageCaption',
        'chat_id': chatId,
        'message_id': draft.messageId,
        'caption': formatted.toTdlib(),
      });
    } else {
      _client.send({
        '@type': 'editMessageText',
        'chat_id': chatId,
        'message_id': draft.messageId,
        'input_message_content': {
          '@type': 'inputMessageText',
          'text': formatted.toTdlib(),
        },
      });
    }

    _editingMessage = null;
    notifyListeners();
  }

  void deleteMessages(List<int> messageIds, {required bool revoke}) {
    final chatId = _activeChatId;
    if (chatId == null || messageIds.isEmpty) {
      return;
    }

    _client.send({
      '@type': 'deleteMessages',
      'chat_id': chatId,
      'message_ids': messageIds,
      'revoke': revoke,
    });
  }

  void deleteMessage(int messageId, {required bool revoke}) {
    deleteMessages([messageId], revoke: revoke);
  }

  void deleteSelectedMessages({required bool revoke}) {
    if (_selectedMessageIds.isEmpty) {
      return;
    }
    final ids = _selectedMessageIds.toList();
    deleteMessages(ids, revoke: revoke);
    _exitSelectionMode();
    notifyListeners();
  }

  void setScheduledSendAt(DateTime? value) {
    _scheduledSendAt = value;
    notifyListeners();
  }

  void clearScheduledSendAt() {
    if (_scheduledSendAt == null) {
      return;
    }
    _scheduledSendAt = null;
    notifyListeners();
  }

  void enterSelectionMode({int? initialMessageId}) {
    _selectionMode = true;
    _selectedMessageIds.clear();
    if (initialMessageId != null) {
      _selectedMessageIds.add(initialMessageId);
    }
    notifyListeners();
  }

  void exitSelectionMode() {
    _exitSelectionMode();
    notifyListeners();
  }

  void _exitSelectionMode() {
    _selectionMode = false;
    _selectedMessageIds.clear();
  }

  void toggleMessageSelection(int messageId) {
    if (!_selectionMode) {
      enterSelectionMode(initialMessageId: messageId);
      return;
    }

    if (_selectedMessageIds.contains(messageId)) {
      _selectedMessageIds.remove(messageId);
      if (_selectedMessageIds.isEmpty) {
        _selectionMode = false;
      }
    } else {
      _selectedMessageIds.add(messageId);
    }
    notifyListeners();
  }

  void sendText(String raw) {
    if (_editingMessage != null) {
      saveEdit(raw);
      return;
    }

    final chatId = _activeChatId;
    final formatted = FormattedTextBuilder.buildFromComposer(raw);
    if (chatId == null || formatted.text.trim().isEmpty) {
      return;
    }

    final payload = <String, dynamic>{
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': formatted.toTdlib(),
      },
    };

    final reply = _pendingReply;
    if (reply != null) {
      payload['reply_to'] = {
        '@type': 'inputMessageReplyToMessage',
        'message_id': reply.messageId,
      };
    }

    if (_scheduledSendAt != null) {
      payload['options'] = {
        '@type': 'messageSendOptions',
        'scheduling_state': MessageSchedulingAtDate(sendAt: _scheduledSendAt!).toTdlib(),
      };
    }

    _client.send(payload);
    _pendingReply = null;
    _scheduledSendAt = null;
    sendChatAction(OutgoingChatAction.cancel);
    notifyListeners();
  }

  Future<void> sendFile(String path) async {
    await sendDocument(path);
  }

  Future<void> sendDocument(String path, {FormattedText? caption}) async {
    final chatId = _activeChatId;
    if (chatId == null) {
      return;
    }

    _client.send(_buildSendPayload(
      chatId: chatId,
      inputMessageContent: {
        '@type': 'inputMessageDocument',
        'document': {
          '@type': 'inputFileLocal',
          'path': path,
        },
        if (caption != null && caption.text.isNotEmpty)
          'caption': caption.toTdlib(),
      },
    ));
    _clearComposerStateAfterSend();
  }

  Future<void> sendPhoto(String path, {FormattedText? caption}) async {
    final chatId = _activeChatId;
    if (chatId == null) {
      return;
    }

    _client.send(_buildSendPayload(
      chatId: chatId,
      inputMessageContent: {
        '@type': 'inputMessagePhoto',
        'photo': {
          '@type': 'inputFileLocal',
          'path': path,
        },
        if (caption != null && caption.text.isNotEmpty)
          'caption': caption.toTdlib(),
      },
    ));
    _clearComposerStateAfterSend();
  }

  Future<void> sendVideo(String path, {FormattedText? caption}) async {
    final chatId = _activeChatId;
    if (chatId == null) {
      return;
    }

    _client.send(_buildSendPayload(
      chatId: chatId,
      inputMessageContent: {
        '@type': 'inputMessageVideo',
        'video': {
          '@type': 'inputFileLocal',
          'path': path,
        },
        'supports_streaming': true,
        if (caption != null && caption.text.isNotEmpty)
          'caption': caption.toTdlib(),
      },
    ));
    _clearComposerStateAfterSend();
  }

  Future<void> sendVideoNote(String path) async {
    final chatId = _activeChatId;
    if (chatId == null) {
      return;
    }

    _client.send(_buildSendPayload(
      chatId: chatId,
      inputMessageContent: {
        '@type': 'inputMessageVideoNote',
        'video_note': {
          '@type': 'inputFileLocal',
          'path': path,
        },
      },
    ));
    _clearComposerStateAfterSend();
  }

  Future<void> sendVoiceNote({
    required String path,
    required int durationSeconds,
    List<int> waveform = const [],
  }) async {
    final chatId = _activeChatId;
    if (chatId == null) {
      return;
    }

    _client.send(_buildSendPayload(
      chatId: chatId,
      inputMessageContent: {
        '@type': 'inputMessageVoiceNote',
        'voice_note': {
          '@type': 'inputFileLocal',
          'path': path,
        },
        'duration': durationSeconds,
        'waveform': waveform,
      },
    ));
    _clearComposerStateAfterSend();
  }

  Future<void> sendAudio(String path, {FormattedText? caption}) async {
    final chatId = _activeChatId;
    if (chatId == null) {
      return;
    }

    _client.send(_buildSendPayload(
      chatId: chatId,
      inputMessageContent: {
        '@type': 'inputMessageAudio',
        'audio': {
          '@type': 'inputFileLocal',
          'path': path,
        },
        if (caption != null && caption.text.isNotEmpty)
          'caption': caption.toTdlib(),
      },
    ));
    _clearComposerStateAfterSend();
  }

  void uploadFile(int fileId) {
    _client.send({
      '@type': 'uploadFile',
      'file_id': fileId,
      'priority': 32,
    });
  }

  void cancelUploadFile(int fileId) {
    _client.send({
      '@type': 'cancelUploadFile',
      'file_id': fileId,
    });
    _fileTransfers.remove(fileId);
    _clearFileTransferOnMessages(fileId);
    notifyListeners();
  }

  void cancelDownloadFile(int fileId) {
    _client.send({
      '@type': 'cancelDownloadFile',
      'file_id': fileId,
      'only_if_pending': false,
    });
    _fileTransfers.remove(fileId);
    _clearFileTransferOnMessages(fileId);
    notifyListeners();
  }

  void cancelMessageTransfer(ChatMessage message) {
    final fileId = message.mediaFileId ?? message.coverFileId;
    if (fileId == null) {
      return;
    }
    final transfer = message.fileTransfer ?? _fileTransfers[fileId];
    if (transfer?.isUpload ?? message.isOutgoing) {
      cancelUploadFile(fileId);
    } else {
      cancelDownloadFile(fileId);
    }
  }

  void downloadMessageMedia(ChatMessage message) {
    final fileId = message.mediaFileId;
    if (fileId == null) {
      return;
    }
    if (_mediaCache != null) {
      _mediaCache.requestDownload(fileId);
      return;
    }
    _client.send({
      '@type': 'downloadFile',
      'file_id': fileId,
      'priority': 32,
      'offset': 0,
      'limit': 0,
      'synchronous': false,
    });
  }

  void deleteMessageFromCache(ChatMessage message) {
    final fileId = message.mediaFileId;
    if (fileId == null) {
      return;
    }
    _mediaCache?.deleteCachedFile(fileId);
    final index = _messages.indexWhere((item) => item.id == message.id);
    if (index >= 0) {
      final current = _messages[index];
      _messages[index] = current.copyWith(
        localFilePath: null,
        content: MessageContent(
          kind: current.content.kind,
          preview: current.content.preview,
          formattedText: current.content.formattedText,
          caption: current.content.caption,
          formattedCaption: current.content.formattedCaption,
          fileName: current.content.fileName,
          poll: current.content.poll,
          videoInfo: current.content.videoInfo,
          voiceInfo: current.content.voiceInfo,
          audioInfo: current.content.audioInfo,
          documentInfo: current.content.documentInfo,
          fileSizeBytes: current.content.fileSizeBytes,
        ),
      );
      notifyListeners();
    }
  }

  Future<void> sendMediaAlbum(List<String> paths) async {
    final chatId = _activeChatId;
    if (chatId == null || paths.isEmpty) {
      return;
    }

    if (paths.length == 1) {
      await sendPhoto(paths.first);
      return;
    }

    final contents = paths.map((path) {
      final lower = path.toLowerCase();
      if (_isVideoPath(lower)) {
        return {
          '@type': 'inputMessageVideo',
          'video': {
            '@type': 'inputFileLocal',
            'path': path,
          },
          'supports_streaming': true,
        };
      }
      return {
        '@type': 'inputMessagePhoto',
        'photo': {
          '@type': 'inputFileLocal',
          'path': path,
        },
      };
    }).toList();

    final payload = <String, dynamic>{
      '@type': 'sendMessageAlbum',
      'chat_id': chatId,
      'input_message_contents': contents,
    };

    final options = _sendOptionsMap();
    if (options != null) {
      payload['options'] = options;
    }

    final reply = _pendingReply;
    if (reply != null) {
      payload['reply_to'] = {
        '@type': 'inputMessageReplyToMessage',
        'message_id': reply.messageId,
      };
    }

    _client.send(payload);
    _clearComposerStateAfterSend();
  }

  Map<String, dynamic> _buildSendPayload({
    required int chatId,
    required Map<String, dynamic> inputMessageContent,
  }) {
    final payload = <String, dynamic>{
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': inputMessageContent,
    };

    final options = _sendOptionsMap();
    if (options != null) {
      payload['options'] = options;
    }

    final reply = _pendingReply;
    if (reply != null) {
      payload['reply_to'] = {
        '@type': 'inputMessageReplyToMessage',
        'message_id': reply.messageId,
      };
    }

    return payload;
  }

  Map<String, dynamic>? _sendOptionsMap() {
    if (_scheduledSendAt == null) {
      return null;
    }
    return {
      '@type': 'messageSendOptions',
      'scheduling_state':
          MessageSchedulingAtDate(sendAt: _scheduledSendAt!).toTdlib(),
    };
  }

  void _clearComposerStateAfterSend() {
    _pendingReply = null;
    _scheduledSendAt = null;
    sendChatAction(OutgoingChatAction.cancel);
    notifyListeners();
  }

  static bool _isVideoPath(String lowerPath) {
    return lowerPath.endsWith('.mp4') ||
        lowerPath.endsWith('.mov') ||
        lowerPath.endsWith('.webm') ||
        lowerPath.endsWith('.mkv');
  }

  void sendTypingAction() {
    sendChatAction(OutgoingChatAction.typing);
  }

  void sendChatAction(OutgoingChatAction action) {
    final chatId = _activeChatId;
    if (chatId == null) {
      return;
    }

    final actionType = switch (action) {
      OutgoingChatAction.typing => 'chatActionTyping',
      OutgoingChatAction.recordingVoice => 'chatActionRecordingVoiceNote',
      OutgoingChatAction.choosingSticker => 'chatActionChoosingSticker',
      OutgoingChatAction.cancel => 'chatActionCancel',
    };

    _client.send({
      '@type': 'sendChatAction',
      'chat_id': chatId,
      'action': {'@type': actionType},
    });
  }

  void forwardSelectedMessages({
    required int toChatId,
    bool withoutAuthor = false,
    bool removeCaption = false,
  }) {
    final fromChatId = _activeChatId;
    if (fromChatId == null || _selectedMessageIds.isEmpty) {
      return;
    }

    final messageIds = _selectedMessageIds.toList()..sort();
    _client.send({
      '@type': 'forwardMessages',
      'chat_id': toChatId,
      'from_chat_id': fromChatId,
      'message_ids': messageIds,
      'options': {
        '@type': 'messageSendOptions',
        'send_copy': withoutAuthor,
      },
      'remove_caption': removeCaption,
    });

    _exitSelectionMode();
    notifyListeners();
  }

  void rescheduleMessage(int chatId, int messageId, DateTime sendAt) {
    _client.send({
      '@type': 'editMessageSchedulingState',
      'chat_id': chatId,
      'message_id': messageId,
      'scheduling_state': MessageSchedulingAtDate(sendAt: sendAt).toTdlib(),
    });
  }

  void addMessageReaction(int messageId, String emoji) {
    final chatId = _activeChatId;
    if (chatId == null) {
      return;
    }
    _client.send({
      '@type': 'addMessageReaction',
      'chat_id': chatId,
      'message_id': messageId,
      'reaction_type': {
        '@type': 'reactionTypeEmoji',
        'emoji': emoji,
      },
      'is_big': false,
      'update_recent_reactions': true,
    });
  }

  void removeMessageReaction(int messageId, String emoji) {
    final chatId = _activeChatId;
    if (chatId == null) {
      return;
    }
    _client.send({
      '@type': 'removeMessageReaction',
      'chat_id': chatId,
      'message_id': messageId,
      'reaction_type': {
        '@type': 'reactionTypeEmoji',
        'emoji': emoji,
      },
    });
  }

  void toggleMessageReaction(int messageId, String emoji) {
    final message = messageById(messageId);
    final existing = message?.reactions.where((r) => r.emoji == emoji);
    if (existing != null && existing.isNotEmpty && existing.first.isChosen) {
      removeMessageReaction(messageId, emoji);
    } else {
      addMessageReaction(messageId, emoji);
    }
  }

  void sendPoll({
    required String question,
    required List<String> options,
    bool isAnonymous = true,
    bool allowMultipleAnswers = false,
    PollKind kind = PollKind.regular,
    int? correctOptionId,
  }) {
    final chatId = _activeChatId;
    if (chatId == null || question.trim().isEmpty || options.length < 2) {
      return;
    }

    final pollOptions = options
        .map(
          (option) => {
            '@type': 'pollOption',
            'text': {
              '@type': 'formattedText',
              'text': option.trim(),
              'entities': [],
            },
          },
        )
        .toList();

    final pollType = kind == PollKind.quiz
        ? {
            '@type': 'pollTypeQuiz',
            'correct_option_id': correctOptionId ?? 0,
            'explanation': {
              '@type': 'formattedText',
              'text': '',
              'entities': [],
            },
          }
        : {
            '@type': 'pollTypeRegular',
            'allow_multiple_answers': allowMultipleAnswers,
          };

    _client.send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessagePoll',
        'question': {
          '@type': 'formattedText',
          'text': question.trim(),
          'entities': [],
        },
        'options': pollOptions,
        'is_anonymous': isAnonymous,
        'type': pollType,
        'open_period': 0,
        'close_date': 0,
      },
    });
  }

  void setPollAnswer(int messageId, List<int> optionIds) {
    final chatId = _activeChatId;
    if (chatId == null || optionIds.isEmpty) {
      return;
    }
    _client.send({
      '@type': 'setPollAnswer',
      'chat_id': chatId,
      'message_id': messageId,
      'option_ids': optionIds,
    });
  }

  void answerCallbackQuery(String callbackQueryId, {String? text}) {
    _client.send({
      '@type': 'answerCallbackQuery',
      'callback_query_id': callbackQueryId,
      'text': text,
      'show_alert': false,
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
      case 'updateChatReadOutbox':
        _handleUpdateChatReadOutbox(update);
      case 'updateChatIsMarkedAsUnread':
        _handleUpdateChatIsMarkedAsUnread(update);
      case 'chats':
        _handleChats(update);
      case 'foundMessages':
        _handleFoundMessages(update);
      case 'messages':
        _handleMessages(update);
      case 'message':
        _handleSingleMessage(update);
      case 'updateNewMessage':
        _handleNewMessage(update);
      case 'updateMessageSendSucceeded':
        _handleSendSucceeded(update);
      case 'updateMessageEdited':
        _handleMessageEdited(update);
      case 'updateDeleteMessages':
        _handleDeleteMessages(update);
      case 'updateMessageContent':
        _handleMessageContent(update);
      case 'updateMessageReactions':
        _handleMessageReactions(update);
      case 'updateMessageInteractionInfo':
        _handleMessageInteractionInfo(update);
      case 'updateNewCallbackQuery':
        _handleNewCallbackQuery(update);
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
      return;
    }

    if (extra.startsWith('searchChats_') || extra.startsWith('searchMessages_')) {
      final requestId = int.tryParse(extra.split('_').last);
      if (requestId == _searchRequestId) {
        _searchError = update['message'] as String? ?? 'Ошибка поиска';
        _completeSearchRequest();
        notifyListeners();
      }
      return;
    }

    if (extra.startsWith('newChatSearch_') ||
        extra.startsWith('newChatSearchLocal_')) {
      final prefix = extra.startsWith('newChatSearchLocal_')
          ? 'newChatSearchLocal_'
          : 'newChatSearch_';
      final requestId = int.tryParse(extra.substring(prefix.length));
      if (requestId == _newChatSearchRequestId) {
        _completeNewChatSearchRequest();
        notifyListeners();
      }
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
        isMarkedAsUnread: summary.isMarkedAsUnread,
        canBeDeletedOnlyForSelf: summary.canBeDeletedOnlyForSelf,
        canBeDeletedForAllUsers: summary.canBeDeletedForAllUsers,
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

  void _handleUpdateChatReadOutbox(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    if (chatId == null) {
      return;
    }

    _lastReadOutboxMessageId[chatId] =
        update['last_read_outbox_message_id'] as int? ?? 0;
    if (chatId == _activeChatId) {
      _refreshDeliveryStatuses();
    }
  }

  void _handleUpdateChatIsMarkedAsUnread(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    if (chatId == null) {
      return;
    }

    final chat = _chatsById[chatId];
    if (chat == null) {
      return;
    }

    _chatsById[chatId] = chat.copyWith(
      isMarkedAsUnread: update['is_marked_as_unread'] as bool? ?? false,
    );
    notifyListeners();
  }

  void _handleChats(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra?.startsWith('searchChats_') ?? false) {
      _handleSearchChats(update, extra!);
      return;
    }
    if (extra?.startsWith('newChatSearchLocal_') ?? false) {
      _handleNewChatSearch(update, extra!, local: true);
      return;
    }
    if (extra?.startsWith('newChatSearch_') ?? false) {
      _handleNewChatSearch(update, extra!, local: false);
      return;
    }

    final chatIds = (update['chat_ids'] as List<dynamic>? ?? []).cast<int>();
    for (final chatId in chatIds) {
      _client.send({'@type': 'getChat', 'chat_id': chatId});
    }
  }

  void _handleSearchChats(Map<String, dynamic> update, String extra) {
    final requestId = int.tryParse(extra.substring('searchChats_'.length));
    if (requestId != _searchRequestId) {
      return;
    }

    final chatIds = (update['chat_ids'] as List<dynamic>? ?? []).cast<int>();
    _searchChatIds = chatIds;
    for (final chatId in chatIds) {
      if (!_chatsById.containsKey(chatId)) {
        _client.send({'@type': 'getChat', 'chat_id': chatId});
      }
    }
    _completeSearchRequest();
  }

  void _handleNewChatSearch(
    Map<String, dynamic> update,
    String extra, {
    required bool local,
  }) {
    final prefix = local ? 'newChatSearchLocal_' : 'newChatSearch_';
    final requestId = int.tryParse(extra.substring(prefix.length));
    if (requestId != _newChatSearchRequestId) {
      return;
    }

    final chatIds = (update['chat_ids'] as List<dynamic>? ?? []).cast<int>();
    _newChatSearchIds = {
      ..._newChatSearchIds,
      ...chatIds,
    }.toList();
    for (final chatId in chatIds) {
      if (!_chatsById.containsKey(chatId)) {
        _client.send({'@type': 'getChat', 'chat_id': chatId});
      }
    }
    _completeNewChatSearchRequest();
  }

  void _completeNewChatSearchRequest() {
    _pendingNewChatSearchRequests =
        (_pendingNewChatSearchRequests - 1).clamp(0, 2);
    if (_pendingNewChatSearchRequests == 0) {
      _isNewChatSearchLoading = false;
      notifyListeners();
    }
  }

  void _handleFoundMessages(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra?.startsWith('searchMessages_') != true) {
      return;
    }

    final requestId = int.tryParse(extra!.substring('searchMessages_'.length));
    if (requestId != _searchRequestId) {
      return;
    }

    final hits = TdlibChatParser.parseFoundMessages(update);
    _searchMessages = hits.map((hit) {
      final title = _chatsById[hit.chatId]?.title;
      if (title == null) {
        _client.send({'@type': 'getChat', 'chat_id': hit.chatId});
      }
      return hit.copyWith(chatTitle: title);
    }).toList();
    _completeSearchRequest();
  }

  void _completeSearchRequest() {
    _pendingSearchRequests = (_pendingSearchRequests - 1).clamp(0, 2);
    if (_pendingSearchRequests == 0) {
      _isSearchLoading = false;
      notifyListeners();
    }
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
    final lastRead = _lastReadOutboxMessageId[chatId] ?? 0;
    final parsed = rawMessages
        .whereType<Map<String, dynamic>>()
        .map(
          (raw) => TdlibChatParser.parseMessage(
            raw,
            lastReadOutboxMessageId: lastRead,
          ),
        )
        .whereType<ChatMessage>()
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
    final message = _parseMessage(update);
    if (message == null) {
      return;
    }
    _insertMessage(message);
  }

  void _handleNewMessage(Map<String, dynamic> update) {
    final message = _parseMessage(
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
    final oldMessageId = update['old_message_id'] as int?;
    final message = _parseMessage(
      update['message'] as Map<String, dynamic>,
    );
    if (message == null) {
      return;
    }

    if (oldMessageId != null && oldMessageId != message.id) {
      final pendingIndex = _messages.indexWhere((item) => item.id == oldMessageId);
      if (pendingIndex >= 0) {
        _messages[pendingIndex] = message;
        notifyListeners();
        return;
      }
    }
    _replaceMessage(message);
  }

  void _handleMessageEdited(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    final messageId = update['message_id'] as int?;
    if (chatId != _activeChatId || messageId == null) {
      return;
    }

    final editDateSeconds = update['edit_date'] as int? ?? 0;
    final editDate = editDateSeconds > 0
        ? DateTime.fromMillisecondsSinceEpoch(editDateSeconds * 1000)
        : null;

    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index >= 0) {
      _messages[index] = _messages[index].copyWith(editDate: editDate);
      notifyListeners();
    }
  }

  void _handleMessageContent(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    final messageId = update['message_id'] as int?;
    final newContent = update['new_content'] as Map<String, dynamic>?;
    if (chatId != _activeChatId || messageId == null || newContent == null) {
      return;
    }

    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index < 0) {
      return;
    }

    final current = _messages[index];
    _messages[index] = current.copyWith(
      content: MessageContent.fromTdlib(newContent),
      mediaFileId:
          MessageContent.parseMediaFileId(newContent) ?? current.mediaFileId,
      coverFileId:
          MessageContent.parseCoverFileId(newContent) ?? current.coverFileId,
    );
    _requestDownloadForMessage(_messages[index]);
    notifyListeners();
  }

  void _handleDeleteMessages(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    if (chatId != _activeChatId) {
      return;
    }

    final ids = (update['message_ids'] as List<dynamic>? ?? []).cast<int>();
    if (ids.isEmpty) {
      return;
    }

    final isPermanent = update['is_permanent'] as bool? ?? true;
    if (isPermanent) {
      _messages.removeWhere((message) => ids.contains(message.id));
      _selectedMessageIds.removeWhere((id) => ids.contains(id));
      if (_selectedMessageIds.isEmpty) {
        _selectionMode = false;
      }
    } else {
      for (var i = 0; i < _messages.length; i++) {
        if (ids.contains(_messages[i].id)) {
          _messages[i] = _messages[i].copyWith(
            isDeleted: true,
            content: const MessageContent(
              kind: MessageKind.text,
              preview: 'Сообщение удалено',
            ),
          );
        }
      }
    }
    notifyListeners();
  }

  void _handleMessageReactions(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    final messageId = update['message_id'] as int?;
    if (chatId != _activeChatId || messageId == null) {
      return;
    }

    final reactions = MessageEnrichmentParser.parseReactions(
      update['reactions'] as Map<String, dynamic>?,
    );
    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index >= 0) {
      _messages[index] = _messages[index].copyWith(reactions: reactions);
      notifyListeners();
    }
  }

  void _handleMessageInteractionInfo(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    final messageId = update['message_id'] as int?;
    if (chatId != _activeChatId || messageId == null) {
      return;
    }

    final info = MessageInteractionInfo.fromTdlib(
      update['interaction_info'] as Map<String, dynamic>?,
    );
    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index >= 0) {
      _messages[index] = _messages[index].copyWith(interactionInfo: info);
      notifyListeners();
    }
  }

  void _handleNewCallbackQuery(Map<String, dynamic> update) {
    final callbackQueryId = update['id'] as String?;
    if (callbackQueryId == null) {
      return;
    }
    answerCallbackQuery(callbackQueryId);
  }

  void _handleTyping(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    if (chatId != _activeChatId) {
      return;
    }

    _typingStatusClearTimer?.cancel();
    _typingStatus = TdlibChatParser.parseTypingAction(update);
    if (_typingStatus != null) {
      _typingStatusClearTimer = Timer(const Duration(seconds: 6), () {
        _typingStatus = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void _handleFileUpdate(Map<String, dynamic> update) {
    final file = update['file'] as Map<String, dynamic>?;
    if (file == null) {
      return;
    }

    final fileId = file['id'] as int?;
    if (fileId == null) {
      return;
    }

    final transfer = FileTransferState.fromTdlibFile(file);
    if (transfer.isActive) {
      _fileTransfers[fileId] = transfer;
    } else if (transfer.isCompleted) {
      _fileTransfers.remove(fileId);
    } else {
      _fileTransfers.remove(fileId);
    }

    final local = file['local'] as Map<String, dynamic>?;
    final localPath = local?['path'] as String?;
    final isDownloadingCompleted =
        local?['is_downloading_completed'] as bool? ?? false;
    final hasLocalPath =
        localPath != null && localPath.isNotEmpty && isDownloadingCompleted;

    var messagesChanged = false;
    for (var i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      ChatMessage? updated;

      if (message.mediaFileId == fileId) {
        updated = message.copyWith(
          fileTransfer: transfer.isActive ? transfer : null,
          clearFileTransfer: !transfer.isActive,
          localFilePath: hasLocalPath ? localPath : message.localFilePath,
          content: hasLocalPath
              ? MessageContent(
                  kind: message.content.kind,
                  preview: message.content.preview,
                  formattedText: message.content.formattedText,
                  caption: message.content.caption,
                  formattedCaption: message.content.formattedCaption,
                  localPath: localPath,
                  fileName: message.content.fileName,
                  poll: message.content.poll,
                  videoInfo: message.content.videoInfo,
                  voiceInfo: message.content.voiceInfo,
                  audioInfo: message.content.audioInfo,
                  documentInfo: message.content.documentInfo,
                  fileSizeBytes: message.content.fileSizeBytes,
                )
              : message.content,
        );
      } else if (message.coverFileId == fileId) {
        if (hasLocalPath) {
          updated = message.copyWith(coverLocalPath: localPath);
        } else if (transfer.isActive) {
          updated = message.copyWith(fileTransfer: transfer);
        } else if (message.fileTransfer != null) {
          updated = message.copyWith(clearFileTransfer: true);
        }
      }

      if (updated != null) {
        _messages[i] = updated;
        messagesChanged = true;
      }
    }

    var chatsChanged = false;
    if (hasLocalPath) {
      for (final entry in _chatsById.entries) {
        if (entry.value.avatarFileId == fileId) {
          _chatsById[entry.key] =
              entry.value.copyWith(avatarLocalPath: localPath);
          chatsChanged = true;
        }
      }
    }

    if (messagesChanged || chatsChanged || transfer.isActive) {
      notifyListeners();
    }
  }

  void _clearFileTransferOnMessages(int fileId) {
    for (var i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      if ((message.mediaFileId == fileId || message.coverFileId == fileId) &&
          message.fileTransfer != null) {
        _messages[i] = message.copyWith(clearFileTransfer: true);
      }
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
        message.content.kind == MessageKind.poll ||
        message.mediaFileId == null) {
      _requestCoverDownload(message);
      return;
    }

    if (message.localFilePath != null) {
      _requestCoverDownload(message);
      return;
    }

    final cache = _mediaCache;
    if (cache != null && !cache.shouldAutoDownload(message)) {
      _requestCoverDownload(message);
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
    _requestCoverDownload(message);
  }

  void _requestCoverDownload(ChatMessage message) {
    final coverId = message.coverFileId;
    if (coverId == null || message.coverLocalPath != null) {
      return;
    }
    final cache = _mediaCache;
    if (cache != null && !cache.shouldAutoDownloadCover(message)) {
      return;
    }
    _client.send({
      '@type': 'downloadFile',
      'file_id': coverId,
      'priority': 8,
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
    _searchDebounce?.cancel();
    _newChatSearchDebounce?.cancel();
    _typingStatusClearTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
