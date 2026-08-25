import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/anti_recall_models.dart';
import '../../models/audio_models.dart';
import '../../models/chat_models.dart';
import '../../models/channel_models.dart';
import '../../models/chat_info_models.dart';
import '../../models/forum_models.dart';
import '../../models/formatted_text.dart';
import '../../models/plugin_models.dart';
import '../../models/group_models.dart';
import '../../models/location_models.dart';
import '../../models/message_enrichment.dart';
import '../features/anti_recall_store.dart';
import '../features/riogram_features_manager.dart';
import '../integrations/external_integrations_manager.dart';
import '../plugins/plugin_manager.dart';
import '../location/live_location_tracker.dart';
import '../media/media_cache_manager.dart';
import '../notifications/notification_settings_manager.dart';
import '../notifications/notification_service.dart';
import '../privacy/ad_block_filter.dart';
import '../privacy/security_privacy_manager.dart';
import '../../models/sticker_models.dart';
import '../tdlib/tdlib_client.dart';
import 'formatted_text_builder.dart';
import 'tdlib_forum_parser.dart';
import 'tdlib_chat_info_parser.dart';
import 'tdlib_chat_parser.dart';
import 'tdlib_group_message_parser.dart';
import '../tdlib/tdlib_json.dart';

/// Управление списком чатов и активной перепиской.
class ChatManager extends ChangeNotifier {
  ChatManager({
    required TdlibClient client,
    NotificationService? notificationService,
    NotificationSettingsManager? notificationSettings,
    MediaCacheManager? mediaCache,
    GhostModeManager? ghostMode,
    AntiRecallStore? antiRecallStore,
    RioGramMediaFeaturesManager? mediaFeatures,
    SecurityPrivacyManager? securityPrivacy,
    ExternalIntegrationsManager? externalIntegrations,
    PluginManager? pluginManager,
  })  : _client = client,
        _notifications = notificationService ?? NotificationService(),
        _notificationSettings = notificationSettings,
        _mediaCache = mediaCache,
        _ghostMode = ghostMode,
        _antiRecallStore = antiRecallStore,
        _mediaFeatures = mediaFeatures,
        _securityPrivacy = securityPrivacy,
        _externalIntegrations = externalIntegrations,
        _pluginManager = pluginManager;

  final TdlibClient _client;
  final NotificationService _notifications;
  final NotificationSettingsManager? _notificationSettings;
  final MediaCacheManager? _mediaCache;
  final GhostModeManager? _ghostMode;
  final AntiRecallStore? _antiRecallStore;
  final RioGramMediaFeaturesManager? _mediaFeatures;
  final SecurityPrivacyManager? _securityPrivacy;
  final ExternalIntegrationsManager? _externalIntegrations;
  final PluginManager? _pluginManager;
  final LiveLocationTracker _liveLocationTracker = LiveLocationTracker();

  final Map<int, ChatSummary> _chatsById = {};
  final Map<int, bool> _botUsers = {};
  final Map<int, String> _userDisplayNames = {};
  final Map<int, ChatDetailInfo> _chatInfoById = {};
  final Map<int, List<ChatMemberInfo>> _chatMembersById = {};
  final Map<int, int> _chatMembersTotalCount = {};
  final List<ChatMessage> _messages = [];
  final List<ChatFolderTab> _chatFolders = [];

  ChatListKey _activeChatList = const ChatListMain();
  int? _myUserId;
  int? _activeChatId;
  String? _typingStatus;
  bool _isLoadingMessages = false;
  String? _messagesError;
  Timer? _messagesLoadTimeout;
  /// Сколько сообщений хотим набрать при открытии чата (TDLib часто отдаёт по 1).
  int _historyTargetCount = 50;
  int _historyPagesFetched = 0;
  static const int _historyPageLimit = 50;
  static const int _historyMaxPages = 20;
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
  final Set<int> _newChatSearchPublicIds = {};
  int _chatActionRequestId = 0;
  final Map<String, Completer<int>> _chatActionCompleters = {};
  String? _chatActionError;
  bool _isLoadingChatInfo = false;
  String? _chatInfoError;
  int? _loadingChatInfoForChatId;
  int _chatInfoPendingRequests = 0;

  MessageThreadContext? _messageThreadContext;
  List<ChatMessage> _messageThreadMessages = [];
  bool _isLoadingMessageThread = false;
  String? _messageThreadError;
  String? _pendingThreadPreview;

  int? _activeForumTopicId;
  String? _activeForumTopicName;
  final Map<int, List<ForumTopicSummary>> _forumTopicsByChatId = {};
  final Map<int, int> _forumTopicsTotalCount = {};
  bool _isLoadingForumTopics = false;
  String? _forumTopicsError;
  int? _loadingForumTopicsForChatId;
  ForumTopicsPageOffset _forumTopicsNextOffset = const ForumTopicsPageOffset();

  MessageReplyDraft? _pendingReply;
  DateTime? _scheduledSendAt;
  bool _pendingLiveLocationBroadcast = false;
  LiveLocationMeta? _pendingLiveLocationMeta;
  int? _activeLiveLocationMessageId;
  LiveLocationMeta? _activeLiveLocationMeta;
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
  int? get myUserId => _myUserId;
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

  bool newChatSearchNeedsJoin(int chatId) {
    if (!_newChatSearchPublicIds.contains(chatId)) {
      return false;
    }
    final chat = _chatsById[chatId];
    if (chat == null) {
      return true;
    }
    return !chat.isInList(const ChatListMain());
  }

  void clearChatActionError() {
    _chatActionError = null;
  }

  bool get isNewChatSearchLoading => _isNewChatSearchLoading;
  String? get chatActionError => _chatActionError;
  bool get isLoadingChatInfo => _isLoadingChatInfo;
  String? get chatInfoError => _chatInfoError;
  int? get loadingChatInfoForChatId => _loadingChatInfoForChatId;
  MessageThreadContext? get messageThreadContext => _messageThreadContext;
  List<ChatMessage> get messageThreadMessages =>
      List.unmodifiable(_messageThreadMessages);
  bool get isLoadingMessageThread => _isLoadingMessageThread;
  String? get messageThreadError => _messageThreadError;
  int? get activeForumTopicId => _activeForumTopicId;
  String? get activeForumTopicName => _activeForumTopicName;
  bool get isForumTopicOpen => _activeForumTopicId != null;
  bool get isLoadingForumTopics => _isLoadingForumTopics;
  String? get forumTopicsError => _forumTopicsError;
  int? get loadingForumTopicsForChatId => _loadingForumTopicsForChatId;

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
        .where((chat) => !_shouldHideSponsoredChat(chat))
        .toList()
      ..sort((a, b) => ChatSummary.compareInList(a, b, _activeChatList));
    return visible;
  }

  bool _shouldHideSponsoredChat(ChatSummary chat) {
    return _securityPrivacy?.shouldBlockAds == true &&
        AdBlockFilter.isSponsoredChat(chat);
  }

  ChatSummary? get activeChat {
    if (_activeChatId == null) {
      return null;
    }
    return _chatsById[_activeChatId];
  }

  ChatSummary? chatById(int chatId) => _chatsById[chatId];

  ChatDetailInfo? chatInfoFor(int chatId) => _chatInfoById[chatId];

  List<ChatMemberInfo> chatMembersFor(int chatId) {
    return List.unmodifiable(_chatMembersById[chatId] ?? const []);
  }

  int chatMembersTotalCountFor(int chatId) {
    return _chatMembersTotalCount[chatId] ??
        _chatMembersById[chatId]?.length ??
        0;
  }

  String? userDisplayName(int userId) => _userDisplayNames[userId];

  bool canPinMessagesInChat(int chatId) {
    final info = _chatInfoById[chatId];
    if (info != null) {
      return info.permissions.canPinMessages;
    }
    return false;
  }

  bool get canSendInActiveChat {
    final chatId = _activeChatId;
    if (chatId == null) {
      return false;
    }
    final chat = _chatsById[chatId];
    if (chat == null) {
      return false;
    }
    if (chat.kind != ChatKind.channel) {
      return true;
    }
    return _canPostInChannel(chatId);
  }

  ChannelMembershipKind channelMembershipFor(int chatId) {
    final info = _chatInfoById[chatId];
    if (info == null) {
      return ChannelMembershipKind.unknown;
    }
    if (info.myStatus == ChatMemberStatusKind.left ||
        info.myStatus == ChatMemberStatusKind.banned) {
      return ChannelMembershipKind.notSubscribed;
    }
    if (info.myStatus == ChatMemberStatusKind.unknown) {
      return ChannelMembershipKind.unknown;
    }
    return ChannelMembershipKind.subscribed;
  }

  bool channelHasComments(int chatId) {
    final info = _chatInfoById[chatId];
    return info?.hasLinkedChat == true || info?.linkedChatId != null;
  }

  List<ForumTopicSummary> forumTopicsFor(int chatId) {
    return List.unmodifiable(_forumTopicsByChatId[chatId] ?? const []);
  }

  int forumTopicsTotalCountFor(int chatId) {
    return _forumTopicsTotalCount[chatId] ??
        _forumTopicsByChatId[chatId]?.length ??
        0;
  }

  Future<int> subscribeToChannel(int chatId) => joinChat(chatId);

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
    final message = TdlibChatParser.parseMessage(
      json,
      lastReadOutboxMessageId: _lastReadOutboxForActiveChat(),
    );
    if (message == null) {
      return null;
    }
    return _enrichGroupMessage(json, message);
  }

  GroupMessageNameResolver get _groupNameResolver => GroupMessageNameResolver(
        userName: (userId) => _userDisplayNames[userId] ?? '',
        chatTitle: (chatId) => _chatsById[chatId]?.title ?? '',
      );

  bool get _isAntiRecallEnabled =>
      _mediaFeatures?.antiRecallEnabled == true && _antiRecallStore != null;

  /// Открывает содержимое сообщения (таймер самоуничтожения), если не включён скрытый просмотр.
  void openMessageContentIfAllowed(int chatId, int messageId) {
    if (_ghostMode?.shouldStealthViewSelfDestruct == true) {
      return;
    }
    _client.send({
      '@type': 'openMessageContent',
      'chat_id': chatId,
      'message_id': messageId,
    });
  }

  ChatMessage _enrichGroupMessage(
    Map<String, dynamic> json,
    ChatMessage message,
  ) {
    final senderRaw = json['sender_id'] as Map<String, dynamic>?;
    final senderIds = TdlibGroupMessageParser.parseSenderIds(senderRaw);
    final resolver = _groupNameResolver;

    var senderName = message.senderName;
    if (!message.isOutgoing) {
      senderName ??= TdlibGroupMessageParser.parseSenderDisplayName(
        senderRaw,
        resolver,
      );
    }

    if (senderIds.userId != null) {
      _requestUserIfNeeded(senderIds.userId!);
    }

    final contentMap = json['content'] as Map<String, dynamic>? ?? {};
    var content = message.content;
    final serviceContent = TdlibGroupMessageParser.parseServiceContent(
      contentMap,
      resolver,
      senderId: senderRaw,
    );
    if (serviceContent != null) {
      content = serviceContent;
      for (final userId in serviceContent.serviceUserIds) {
        _requestUserIfNeeded(userId);
      }
    }

    if (senderName == message.senderName &&
        content == message.content &&
        senderIds.userId == message.senderUserId &&
        senderIds.chatId == message.senderChatId) {
      return message;
    }

    return message.copyWith(
      senderName: senderName,
      senderUserId: senderIds.userId,
      senderChatId: senderIds.chatId,
      content: content,
    );
  }

  void _refreshMessagesForUser(int userId) {
    final name = _userDisplayNames[userId];
    if (name == null) {
      return;
    }

    var changed = false;
    for (var i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      var updated = message;

      if (message.senderUserId == userId && message.senderName != name) {
        updated = updated.copyWith(senderName: name);
      }

      final raw = updated.content.serviceContentRaw;
      if (raw != null &&
          updated.content.serviceUserIds.contains(userId)) {
        final serviceContent = TdlibGroupMessageParser.parseServiceContent(
          raw,
          _groupNameResolver,
          senderId: _senderIdFromMessage(updated),
        );
        if (serviceContent != null &&
            serviceContent.preview != updated.content.preview) {
          updated = updated.copyWith(content: serviceContent);
        }
      }

      if (updated != message) {
        _messages[i] = updated;
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  Map<String, dynamic>? _senderIdFromMessage(ChatMessage message) {
    if (message.senderUserId != null) {
      return {
        '@type': 'messageSenderUser',
        'user_id': message.senderUserId,
      };
    }
    if (message.senderChatId != null) {
      return {
        '@type': 'messageSenderChat',
        'chat_id': message.senderChatId,
      };
    }
    return null;
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
          : MessageDeliveryStatus.delivered;
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
      _newChatSearchPublicIds.clear();
      _isNewChatSearchLoading = false;
      _pendingNewChatSearchRequests = 0;
      notifyListeners();
      return;
    }

    _isNewChatSearchLoading = true;
    notifyListeners();

    _newChatSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      final requestId = ++_newChatSearchRequestId;
      var pending = 2;

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

      final username = PublicChatLinkParser.parseUsername(trimmed);
      if (username != null) {
        pending += 1;
        _client.send({
          '@type': 'searchPublicChat',
          'username': username,
          '@extra': 'newChatPublic_$requestId',
        });
      }

      _pendingNewChatSearchRequests = pending;
    });
  }

  void clearNewChatSearch() {
    _newChatSearchDebounce?.cancel();
    _newChatSearchIds = [];
    _newChatSearchPublicIds.clear();
    _isNewChatSearchLoading = false;
    _pendingNewChatSearchRequests = 0;
    notifyListeners();
  }

  Future<int> createSupergroupChat({
    required String title,
    bool isChannel = false,
    String description = '',
    bool isForum = false,
  }) {
    return _sendChatAction(
      request: {
        '@type': 'createNewSupergroupChat',
        'title': title.trim(),
        'is_forum': isForum,
        'is_channel': isChannel,
        'description': description.trim(),
        'message_auto_delete_time': 0,
        'for_import': false,
      },
      extraPrefix: 'createSupergroup',
    );
  }

  Future<int> createBasicGroupChat({
    required String title,
    List<int> userIds = const [],
  }) {
    return _sendCreatedBasicGroupAction(
      request: {
        '@type': 'createNewBasicGroupChat',
        'user_ids': userIds,
        'title': title.trim(),
        'message_auto_delete_time': 0,
      },
      extraPrefix: 'createBasicGroup',
    );
  }

  Future<int> upgradeBasicGroupToSupergroup(int chatId) {
    return _sendChatAction(
      request: {
        '@type': 'upgradeBasicGroupChatToSupergroupChat',
        'chat_id': chatId,
      },
      extraPrefix: 'upgradeBasicGroup',
    );
  }

  Future<int> joinChat(int chatId) {
    return _sendJoinAction(
      request: {
        '@type': 'joinChat',
        'chat_id': chatId,
      },
      extraPrefix: 'joinChat',
    );
  }

  Future<int> joinChatByInviteLink(String inviteLink) {
    return _sendJoinAction(
      request: {
        '@type': 'joinChatByInviteLink',
        'invite_link': inviteLink.trim(),
      },
      extraPrefix: 'joinInvite',
    );
  }

  Future<int> createPrivateChat(int userId) {
    return _sendChatAction(
      request: {
        '@type': 'createPrivateChat',
        'user_id': userId,
        'force': false,
      },
      extraPrefix: 'createPrivateChat',
    );
  }

  void clearChatInfo(int chatId) {
    _chatInfoById.remove(chatId);
    _chatMembersById.remove(chatId);
    _chatMembersTotalCount.remove(chatId);
    if (_loadingChatInfoForChatId == chatId) {
      _loadingChatInfoForChatId = null;
      _isLoadingChatInfo = false;
      _chatInfoPendingRequests = 0;
    }
    notifyListeners();
  }

  void loadChatInfo(int chatId) {
    _loadingChatInfoForChatId = chatId;
    _chatInfoError = null;
    _isLoadingChatInfo = true;
    _chatInfoPendingRequests = 0;
    _chatMembersById.remove(chatId);
    _chatMembersTotalCount.remove(chatId);
    _chatInfoById[chatId] = ChatDetailInfo(chatId: chatId);
    _client.send({
      '@type': 'getChat',
      'chat_id': chatId,
      '@extra': 'chatInfo_chat_$chatId',
    });
    notifyListeners();
  }

  Future<void> leaveChat(int chatId) async {
    _client.send({'@type': 'leaveChat', 'chat_id': chatId});
  }

  void pinChatMessage(int chatId, int messageId) {
    _client.send({
      '@type': 'pinChatMessage',
      'chat_id': chatId,
      'message_id': messageId,
      'disable_notification': false,
      'only_for_self': false,
    });
  }

  void unpinChatMessage(int chatId, int messageId) {
    _client.send({
      '@type': 'unpinChatMessage',
      'chat_id': chatId,
      'message_id': messageId,
    });
  }

  void setChatPermissions(int chatId, ChatPermissionsInfo permissions) {
    _client.send({
      '@type': 'setChatPermissions',
      'chat_id': chatId,
      'permissions': permissions.toTdlib(),
    });
    _mergeChatInfo(
      chatId,
      (_chatInfoById[chatId] ?? ChatDetailInfo(chatId: chatId))
          .copyWithPermissions(permissions),
    );
    notifyListeners();
  }

  void banChatMember(int chatId, int userId) {
    _client.send({
      '@type': 'banChatMember',
      'chat_id': chatId,
      'member_id': {
        '@type': 'messageSenderUser',
        'user_id': userId,
      },
      'banned_until_date': 0,
      'revoke_messages': false,
    });
  }

  void unbanChatMember(int chatId, int userId) {
    _client.send({
      '@type': 'setChatMemberStatus',
      'chat_id': chatId,
      'member_id': {
        '@type': 'messageSenderUser',
        'user_id': userId,
      },
      'status': {'@type': 'chatMemberStatusLeft'},
    });
  }

  void setChatMemberTag(int chatId, int userId, String tag) {
    _client.send({
      '@type': 'setChatMemberTag',
      'chat_id': chatId,
      'user_id': userId,
      'tag': tag.trim(),
    });
  }

  void createPrimaryInviteLink(int chatId) {
    _client.send({
      '@type': 'createChatInviteLink',
      'chat_id': chatId,
      'name': '',
      'expiration_date': 0,
      'member_limit': 0,
      'creates_join_request': false,
      '@extra': 'chatInfo_createInvite_$chatId',
    });
  }

  void fetchMessageThread(
    int channelChatId,
    int channelMessageId, {
    String? postPreview,
  }) {
    _messageThreadContext = null;
    _messageThreadMessages = [];
    _isLoadingMessageThread = true;
    _messageThreadError = null;
    _pendingThreadPreview = postPreview;
    _client.send({
      '@type': 'getMessageThread',
      'chat_id': channelChatId,
      'message_id': channelMessageId,
      '@extra': 'messageThread_${channelChatId}_$channelMessageId',
    });
    notifyListeners();
  }

  void clearMessageThread() {
    _messageThreadContext = null;
    _messageThreadMessages = [];
    _isLoadingMessageThread = false;
    _messageThreadError = null;
    _pendingThreadPreview = null;
    notifyListeners();
  }

  void sendThreadMessage(String raw) {
    final context = _messageThreadContext;
    if (context == null) {
      return;
    }
    final formatted = FormattedTextBuilder.buildFromComposer(raw);
    if (formatted.text.trim().isEmpty) {
      return;
    }
    _client.send({
      '@type': 'sendMessage',
      'chat_id': context.discussionChatId,
      'topic_id': {
        '@type': 'messageTopicThread',
        'message_thread_id': context.messageThreadId,
      },
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': formatted.toTdlib(),
      },
    });
  }

  void clearForumTopics(int chatId) {
    _forumTopicsByChatId.remove(chatId);
    _forumTopicsTotalCount.remove(chatId);
    if (_loadingForumTopicsForChatId == chatId) {
      _loadingForumTopicsForChatId = null;
      _isLoadingForumTopics = false;
      _forumTopicsError = null;
    }
    notifyListeners();
  }

  void loadForumTopics(int chatId, {String query = '', bool loadMore = false}) {
    _loadingForumTopicsForChatId = chatId;
    _isLoadingForumTopics = true;
    _forumTopicsError = null;
    if (!loadMore) {
      _forumTopicsNextOffset = const ForumTopicsPageOffset();
      _forumTopicsByChatId.remove(chatId);
    }
    notifyListeners();

    final offset = loadMore ? _forumTopicsNextOffset : const ForumTopicsPageOffset();
    _client.send({
      '@type': 'getForumTopics',
      'chat_id': chatId,
      'query': query.trim(),
      'offset_date': offset.offsetDate,
      'offset_message_id': offset.offsetMessageId,
      'offset_forum_topic_id': offset.offsetForumTopicId,
      'limit': 50,
      '@extra': loadMore ? 'forumTopicsMore_$chatId' : 'forumTopics_$chatId',
    });
  }

  void createForumTopic(int chatId, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _client.send({
      '@type': 'createForumTopic',
      'chat_id': chatId,
      'name': trimmed,
      'is_name_implicit': false,
      'icon': {
        '@type': 'forumTopicIcon',
        'color': 0x6FB9F0,
        'custom_emoji_id': 0,
      },
      '@extra': 'createForumTopic_$chatId',
    });
  }

  void openForumTopic(
    int chatId,
    int forumTopicId, {
    String? topicName,
  }) {
    _activeChatId = chatId;
    _activeForumTopicId = forumTopicId;
    _activeForumTopicName = topicName;
    _messages.clear();
    _typingStatus = null;
    _messagesError = null;
    _pendingReply = null;
    _scheduledSendAt = null;
    _editingMessage = null;
    _exitSelectionMode();
    _isLoadingMessages = true;
    _historyTargetCount = _historyPageLimit;
    _historyPagesFetched = 0;
    _startMessagesLoadTimeout(chatId);
    notifyListeners();

    _client.send({
      '@type': 'openChat',
      'chat_id': chatId,
      '@extra': 'openChat_$chatId',
    });
    _requestForumTopicHistory(chatId, forumTopicId);
  }

  void clearForumTopicSelection() {
    _activeForumTopicId = null;
    _activeForumTopicName = null;
    notifyListeners();
  }

  Future<int> _sendChatAction({
    required Map<String, dynamic> request,
    required String extraPrefix,
  }) async {
    _chatActionError = null;
    final requestId = ++_chatActionRequestId;
    final extra = '${extraPrefix}_$requestId';
    final completer = Completer<int>();
    _chatActionCompleters[extra] = completer;
    _client.send({...request, '@extra': extra});
    try {
      return await completer.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      _chatActionCompleters.remove(extra);
      _chatActionError = 'Таймаут операции с чатом';
      notifyListeners();
      rethrow;
    }
  }

  Future<int> _sendCreatedBasicGroupAction({
    required Map<String, dynamic> request,
    required String extraPrefix,
  }) async {
    _chatActionError = null;
    final requestId = ++_chatActionRequestId;
    final extra = '${extraPrefix}_$requestId';
    final completer = Completer<int>();
    _chatActionCompleters[extra] = completer;
    _client.send({...request, '@extra': extra});
    try {
      return await completer.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      _chatActionCompleters.remove(extra);
      _chatActionError = 'Таймаут создания группы';
      notifyListeners();
      rethrow;
    }
  }

  Future<int> _sendJoinAction({
    required Map<String, dynamic> request,
    required String extraPrefix,
  }) async {
    _chatActionError = null;
    final requestId = ++_chatActionRequestId;
    final extra = '${extraPrefix}_$requestId';
    final completer = Completer<int>();
    _chatActionCompleters[extra] = completer;
    _client.send({...request, '@extra': extra});
    try {
      return await completer.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      _chatActionCompleters.remove(extra);
      _chatActionError = 'Таймаут вступления в чат';
      notifyListeners();
      rethrow;
    }
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
    _activeForumTopicId = null;
    _activeForumTopicName = null;
    _activeChatId = chatId;
    _messages.clear();
    _typingStatus = null;
    _messagesError = null;
    _pendingReply = null;
    _scheduledSendAt = null;
    _editingMessage = null;
    _exitSelectionMode();
    _isLoadingMessages = true;
    _historyTargetCount = _historyPageLimit;
    _historyPagesFetched = 0;
    _startMessagesLoadTimeout(chatId);
    notifyListeners();

    _client.send({
      '@type': 'openChat',
      'chat_id': chatId,
      '@extra': 'openChat_$chatId',
    });
    _requestChatHistory(chatId, onlyLocal: true);
    _requestChatHistory(chatId, onlyLocal: false);

    final chat = _chatsById[chatId];
    if (chat?.kind == ChatKind.channel) {
      loadChatInfo(chatId);
    }
  }

  void closeChat() {
    if (_activeChatId != null) {
      _client.send({'@type': 'closeChat', 'chat_id': _activeChatId});
    }
    _activeChatId = null;
    _activeForumTopicId = null;
    _activeForumTopicName = null;
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

    if (!canSendInActiveChat) {
      return;
    }

    final chatId = _activeChatId;
    final rawTransformed = _pluginManager?.transformOutgoingText(
          context: PluginMessageContext(
            chatId: chatId ?? 0,
            messageId: 0,
            isOutgoing: true,
          ),
          text: raw,
        ) ??
        raw;
    final formatted = FormattedTextBuilder.buildFromComposer(rawTransformed);
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

    _applyForumTopicToPayload(payload);
    _client.send(payload);
    _externalIntegrations?.mirrorOutgoingText(
      sourceChatId: chatId,
      text: formatted,
    );
    _pendingReply = null;
    _scheduledSendAt = null;
    sendChatAction(OutgoingChatAction.cancel);
    notifyListeners();
  }

  Future<void> sendFile(String path) async {
    if (!_canUploadPath(path)) {
      return;
    }
    await sendDocument(path);
  }

  Future<void> sendDocument(String path, {FormattedText? caption}) async {
    if (!_canUploadPath(path)) {
      return;
    }
    final chatId = _activeChatId;
    if (chatId == null || !canSendInActiveChat) {
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
    if (!_canUploadPath(path)) {
      return;
    }
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
    if (!_canUploadPath(path)) {
      return;
    }
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
    if (!_canUploadPath(path)) {
      return;
    }
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

  Future<void> sendSticker(StickerModel sticker) async {
    final chatId = _activeChatId;
    if (chatId == null) {
      return;
    }

    _client.send(_buildSendPayload(
      chatId: chatId,
      inputMessageContent: sticker.toInputMessageSticker(),
    ));
    _clearComposerStateAfterSend();
  }

  Future<void> sendAnimation(
    AnimationModel animation, {
    FormattedText? caption,
  }) async {
    final chatId = _activeChatId;
    if (chatId == null) {
      return;
    }

    _client.send(_buildSendPayload(
      chatId: chatId,
      inputMessageContent: animation.toInputMessageAnimation(caption: caption),
    ));
    _clearComposerStateAfterSend();
  }

  bool get isLiveLocationBroadcastActive =>
      _activeLiveLocationMessageId != null;

  int? get activeLiveLocationMessageId => _activeLiveLocationMessageId;

  Future<LocationPoint?> getCurrentLocation() =>
      _liveLocationTracker.getCurrentPosition();

  Future<void> sendLocation({
    required double latitude,
    required double longitude,
    double horizontalAccuracy = 0,
  }) async {
    final chatId = _activeChatId;
    if (chatId == null || !canSendInActiveChat) {
      return;
    }

    final point = LocationPoint(
      latitude: latitude,
      longitude: longitude,
      horizontalAccuracy: horizontalAccuracy,
    );
    if (!point.isValid) {
      return;
    }

    _client.send(_buildSendPayload(
      chatId: chatId,
      inputMessageContent: {
        '@type': 'inputMessageLocation',
        'location': point.toTdlib(),
      },
    ));
    _clearComposerStateAfterSend();
  }

  Future<void> sendLiveLocation({
    required double latitude,
    required double longitude,
    int livePeriod = 3600,
    double horizontalAccuracy = 0,
    int heading = 0,
    int proximityAlertRadius = 0,
    bool startBroadcast = false,
  }) async {
    final chatId = _activeChatId;
    if (chatId == null || !canSendInActiveChat) {
      return;
    }

    final point = LocationPoint(
      latitude: latitude,
      longitude: longitude,
      horizontalAccuracy: horizontalAccuracy,
    );
    if (!point.isValid) {
      return;
    }

    final meta = LiveLocationMeta(
      livePeriod: livePeriod.clamp(60, LiveLocationMeta.permanentPeriod),
      heading: heading,
      proximityAlertRadius: proximityAlertRadius,
    );

    if (startBroadcast) {
      _pendingLiveLocationBroadcast = true;
      _pendingLiveLocationMeta = meta;
    }

    _client.send(_buildSendPayload(
      chatId: chatId,
      inputMessageContent: {
        '@type': 'inputMessageLiveLocation',
        'location': meta.toTdlib(point),
      },
    ));
    _clearComposerStateAfterSend();
  }

  Future<void> sendVenue({
    required double latitude,
    required double longitude,
    required String title,
    required String address,
    String provider = '',
    String id = '',
    String type = '',
    double horizontalAccuracy = 0,
  }) async {
    final chatId = _activeChatId;
    if (chatId == null || !canSendInActiveChat) {
      return;
    }

    final venue = VenueInfo(
      location: LocationPoint(
        latitude: latitude,
        longitude: longitude,
        horizontalAccuracy: horizontalAccuracy,
      ),
      title: title.trim(),
      address: address.trim(),
      provider: provider,
      id: id,
      type: type,
    );
    if (!venue.location.isValid || venue.title.isEmpty) {
      return;
    }

    _client.send(_buildSendPayload(
      chatId: chatId,
      inputMessageContent: {
        '@type': 'inputMessageVenue',
        'venue': venue.toTdlib(),
      },
    ));
    _clearComposerStateAfterSend();
  }

  Future<void> sendLocationRequest(LocationSendRequest request) async {
    switch (request.mode) {
      case LocationSendMode.staticPoint:
        await sendLocation(
          latitude: request.point.latitude,
          longitude: request.point.longitude,
          horizontalAccuracy: request.point.horizontalAccuracy,
        );
      case LocationSendMode.liveLocation:
        await sendLiveLocation(
          latitude: request.point.latitude,
          longitude: request.point.longitude,
          livePeriod: request.livePeriod,
          horizontalAccuracy: request.point.horizontalAccuracy,
          startBroadcast: request.startBroadcast,
        );
      case LocationSendMode.venue:
        await sendVenue(
          latitude: request.point.latitude,
          longitude: request.point.longitude,
          title: request.venueTitle,
          address: request.venueAddress,
          horizontalAccuracy: request.point.horizontalAccuracy,
        );
    }
  }

  void editMessageLiveLocation({
    required int messageId,
    required LocationPoint point,
    LiveLocationMeta? meta,
  }) {
    final chatId = _activeChatId;
    if (chatId == null) {
      return;
    }

    final payload = <String, dynamic>{
      '@type': 'editMessageLiveLocation',
      'chat_id': chatId,
      'message_id': messageId,
      'reply_markup': null,
      'location': meta?.toTdlib(point),
    };
    _client.send(payload);
  }

  void stopLiveLocation(int messageId) {
    final chatId = _activeChatId;
    if (chatId == null) {
      return;
    }

    _client.send({
      '@type': 'editMessageLiveLocation',
      'chat_id': chatId,
      'message_id': messageId,
      'reply_markup': null,
      'location': null,
    });

    if (_activeLiveLocationMessageId == messageId) {
      _liveLocationTracker.stop();
      _activeLiveLocationMessageId = null;
      _activeLiveLocationMeta = null;
      notifyListeners();
    }
  }

  Future<bool> startLiveLocationBroadcast(int messageId) async {
    final chatId = _activeChatId;
    if (chatId == null) {
      return false;
    }

    final message = messageById(messageId);
    final info = message?.content.locationInfo;
    if (message == null ||
        message.content.kind != MessageKind.liveLocation ||
        info == null ||
        info.isExpired) {
      return false;
    }

    stopLiveLocationBroadcast();

    final meta = info.liveMeta ??
        LiveLocationMeta(livePeriod: info.expiresIn ?? 3600);
    _activeLiveLocationMessageId = messageId;
    _activeLiveLocationMeta = meta;

    final started = await _liveLocationTracker.start((point) {
      editMessageLiveLocation(
        messageId: messageId,
        point: point,
        meta: _activeLiveLocationMeta,
      );
    });
    if (!started) {
      _activeLiveLocationMessageId = null;
      _activeLiveLocationMeta = null;
      return false;
    }
    notifyListeners();
    return true;
  }

  void stopLiveLocationBroadcast() {
    final chatId = _activeChatId;
    final messageId = _activeLiveLocationMessageId;
    _liveLocationTracker.stop();
    _activeLiveLocationMessageId = null;
    _activeLiveLocationMeta = null;
    if (messageId != null && chatId != null) {
      _client.send({
        '@type': 'editMessageLiveLocation',
        'chat_id': chatId,
        'message_id': messageId,
        'reply_markup': null,
        'location': null,
      });
    }
    notifyListeners();
  }

  void _maybeStartPendingLiveBroadcast(ChatMessage message) {
    if (!_pendingLiveLocationBroadcast || !message.isOutgoing) {
      return;
    }
    if (message.content.kind != MessageKind.liveLocation) {
      return;
    }

    _pendingLiveLocationBroadcast = false;
    final meta = _pendingLiveLocationMeta;
    _pendingLiveLocationMeta = null;
    if (meta != null) {
      _activeLiveLocationMeta = meta;
    }
    unawaited(startLiveLocationBroadcast(message.id));
  }

  Future<void> sendGifInlineResult({
    required int queryId,
    required String resultId,
  }) async {
    final chatId = _activeChatId;
    if (chatId == null) {
      return;
    }

    final payload = <String, dynamic>{
      '@type': 'sendInlineQueryResultMessage',
      'chat_id': chatId,
      'query_id': queryId,
      'result_id': resultId,
      'hide_via_bot': true,
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

    _applyForumTopicToPayload(payload);
    _client.send(payload);
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

    _applyForumTopicToPayload(payload);
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

    _applyForumTopicToPayload(payload);
    return payload;
  }

  void _applyForumTopicToPayload(Map<String, dynamic> payload) {
    final topicId = _activeForumTopicId;
    if (topicId == null) {
      return;
    }
    payload['topic_id'] = {
      '@type': 'messageTopicForum',
      'forum_topic_id': topicId,
    };
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

  bool _canUploadPath(String path) {
    final privacy = _securityPrivacy;
    if (privacy == null || kIsWeb) {
      return true;
    }
    final file = File(path);
    if (!file.existsSync()) {
      return true;
    }
    final error = privacy.validateUploadFileSize(file.lengthSync());
    if (error == null) {
      return true;
    }
    _messagesError = error;
    notifyListeners();
    return false;
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

    if (_ghostMode?.shouldHideTyping == true && action != OutgoingChatAction.cancel) {
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
      if (_activeForumTopicId != null)
        'topic_id': {
          '@type': 'messageTopicForum',
          'forum_topic_id': _activeForumTopicId,
        },
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
    try {
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
          _handleChatResponse(update);
        case 'supergroup':
          _handleSupergroupResponse(update);
        case 'supergroupFullInfo':
          _handleSupergroupFullInfoResponse(update);
        case 'basicGroup':
          _handleBasicGroupResponse(update);
        case 'basicGroupFullInfo':
          _handleBasicGroupFullInfoResponse(update);
        case 'chatMembers':
          _handleChatMembersResponse(update);
        case 'chatInviteLink':
          _handleChatInviteLinkResponse(update);
        case 'messageThreadInfo':
          _handleMessageThreadInfo(update);
        case 'forumTopics':
          _handleForumTopics(update);
        case 'forumTopicInfo':
          _handleForumTopicInfo(update);
        case 'createdBasicGroupChat':
          _handleCreatedBasicGroupChat(update);
        case 'chatJoinResultSuccess':
          _handleChatJoinSuccess(update);
        case 'chatJoinResultRequestSent':
          _handleChatJoinRequestSent(update);
        case 'chatJoinResultDeclined':
          _handleChatJoinDeclined(update);
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
    } catch (error, stackTrace) {
      tdlibDebugLog(
        'ChatManager failed on @$type: $error\n$stackTrace',
      );
    }
  }

  void _handleUser(Map<String, dynamic> user) {
    final userId = tdInt(user['id']);
    if (userId == null) {
      return;
    }

    final extra = user['@extra'] as String?;
    if (extra != null && extra.startsWith('chatInfo_user_')) {
      final chatId = int.tryParse(extra.substring('chatInfo_user_'.length));
      if (chatId != null) {
        _completeChatInfoRequest();
      }
    }

    final firstName = user['first_name'] as String? ?? '';
    final lastName = user['last_name'] as String? ?? '';
    final displayName = '$firstName $lastName'.trim();
    if (displayName.isNotEmpty) {
      _userDisplayNames[userId] = displayName;
      _refreshMemberDisplayNames(userId);
      _refreshMessagesForUser(userId);
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
      return;
    }

    if (extra.startsWith('newChatPublic_')) {
      final requestId = int.tryParse(extra.substring('newChatPublic_'.length));
      if (requestId == _newChatSearchRequestId) {
        _completeNewChatSearchRequest();
        notifyListeners();
      }
      return;
    }

    if (extra.startsWith('chatInfo_members_')) {
      // Ожидаемо для каналов / скрытых списков — не показываем как фатал info.
      if (kDebugMode) {
        debugPrint(
          'ChatManager: members unavailable: '
          '${update['message'] as String? ?? 'unknown'}',
        );
      }
      _completeChatInfoRequest();
      notifyListeners();
      return;
    }

    if (extra.startsWith('chatInfo_')) {
      _chatInfoError = update['message'] as String? ?? 'Ошибка загрузки информации';
      _completeChatInfoRequest();
      notifyListeners();
      return;
    }

    if (extra.startsWith('messageThread_')) {
      _isLoadingMessageThread = false;
      _messageThreadError =
          update['message'] as String? ?? 'Не удалось загрузить комментарии';
      notifyListeners();
      return;
    }

    if (extra.startsWith('forumTopics_') || extra.startsWith('forumTopicsMore_')) {
      _forumTopicsError =
          update['message'] as String? ?? 'Не удалось загрузить темы';
      _isLoadingForumTopics = false;
      notifyListeners();
      return;
    }

    if (extra.startsWith('forumTopicHistory_')) {
      final parts = extra.substring('forumTopicHistory_'.length).split('_');
      if (parts.length == 2 &&
          int.tryParse(parts[0]) == _activeChatId &&
          int.tryParse(parts[1]) == _activeForumTopicId) {
        _messagesLoadTimeout?.cancel();
        _isLoadingMessages = false;
        _messagesError =
            update['message'] as String? ?? 'Не удалось загрузить тему';
        notifyListeners();
      }
      return;
    }

    if (_isChatActionExtra(extra)) {
      _failChatAction(
        extra,
        update['message'] as String? ?? 'Ошибка операции с чатом',
      );
    }
  }

  bool _isChatActionExtra(String extra) {
    return extra.startsWith('createSupergroup_') ||
        extra.startsWith('createBasicGroup_') ||
        extra.startsWith('upgradeBasicGroup_') ||
        extra.startsWith('joinChat_') ||
        extra.startsWith('joinInvite_') ||
        extra.startsWith('createPrivateChat_');
  }

  int? _chatIdFromExtra(String? extra, String prefix) {
    if (extra == null || !extra.startsWith(prefix)) {
      return null;
    }
    return int.tryParse(extra.substring(prefix.length));
  }

  void _requestChatHistory(
    int chatId, {
    required bool onlyLocal,
    int fromMessageId = 0,
  }) {
    if (_activeForumTopicId != null) {
      return;
    }
    _client.send({
      '@type': 'getChatHistory',
      'chat_id': chatId,
      'from_message_id': fromMessageId,
      'offset': 0,
      'limit': _historyPageLimit,
      'only_local': onlyLocal,
      '@extra': onlyLocal
          ? 'getChatHistoryLocal_$chatId'
          : 'getChatHistory_$chatId',
    });
  }

  void _requestForumTopicHistory(
    int chatId,
    int forumTopicId, {
    int fromMessageId = 0,
  }) {
    _client.send({
      '@type': 'getForumTopicHistory',
      'chat_id': chatId,
      'forum_topic_id': forumTopicId,
      'from_message_id': fromMessageId,
      'offset': 0,
      'limit': _historyPageLimit,
      '@extra': 'forumTopicHistory_${chatId}_$forumTopicId',
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
    final chatId = tdInt(update['chat_id']);
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
        basicGroupId: summary.basicGroupId ?? existing.basicGroupId,
        supergroupId: summary.supergroupId ?? existing.supergroupId,
        isForum: summary.isForum || existing.isForum,
        canSendMessages: summary.canSendMessages,
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
    final chatId = tdInt(update['chat_id']);
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
    var lastMessageIsOutgoing = chat.lastMessageIsOutgoing;
    MessageDeliveryStatus? lastMessageDeliveryStatus = chat.lastMessageDeliveryStatus;
    if (lastMessage != null) {
      final content = lastMessage['content'] as Map<String, dynamic>? ?? {};
      preview = MessageContent.fromTdlib(content).preview;
      final dateSeconds = tdIntOr(lastMessage['date']);
      date = DateTime.fromMillisecondsSinceEpoch(dateSeconds * 1000);
      lastMessageIsOutgoing = lastMessage['is_outgoing'] as bool? ?? false;
      lastMessageDeliveryStatus = MessageEnrichmentParser.parseDeliveryStatus(
        lastMessage,
        lastReadOutboxMessageId: _lastReadOutboxMessageId[chatId] ?? 0,
      );
    }

    final positions = TdlibChatParser.parsePositions(update['positions'] as List<dynamic>?);
    _chatsById[chatId] = chat.copyWith(
      lastMessage: preview,
      lastMessageDate: date,
      lastMessageIsOutgoing: lastMessageIsOutgoing,
      lastMessageDeliveryStatus: lastMessageDeliveryStatus,
      positions: positions.isNotEmpty ? positions : chat.positions,
    );
    notifyListeners();
  }

  void _handleUpdateChatPosition(Map<String, dynamic> update) {
    final chatId = tdInt(update['chat_id']);
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
    final chatId = tdInt(update['chat_id']);
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
    final chatId = tdInt(update['chat_id']);
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
    final chatId = tdInt(update['chat_id']);
    if (chatId == null) {
      return;
    }

    final chat = _chatsById[chatId];
    if (chat == null) {
      return;
    }

    _chatsById[chatId] = chat.copyWith(
      unreadCount: tdInt(update['unread_count']) ?? chat.unreadCount,
    );
    notifyListeners();
  }

  void _handleUpdateChatReadOutbox(Map<String, dynamic> update) {
    final chatId = tdInt(update['chat_id']);
    if (chatId == null) {
      return;
    }

    _lastReadOutboxMessageId[chatId] =
        tdIntOr(update['last_read_outbox_message_id']);
    final chat = _chatsById[chatId];
    if (chat != null &&
        chat.lastMessageIsOutgoing &&
        chat.lastMessageDeliveryStatus != null &&
        chat.lastMessageDeliveryStatus != MessageDeliveryStatus.sending &&
        chat.lastMessageDeliveryStatus != MessageDeliveryStatus.failed) {
      _chatsById[chatId] = chat.copyWith(lastMessageDeliveryStatus: MessageDeliveryStatus.read);
      notifyListeners();
    }
    if (chatId == _activeChatId) {
      _refreshDeliveryStatuses();
    }
  }

  void _handleUpdateChatIsMarkedAsUnread(Map<String, dynamic> update) {
    final chatId = tdInt(update['chat_id']);
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
    if (_pendingNewChatSearchRequests <= 0) {
      return;
    }
    _pendingNewChatSearchRequests -= 1;
    if (_pendingNewChatSearchRequests == 0) {
      _isNewChatSearchLoading = false;
      notifyListeners();
    }
  }

  void _handleChatResponse(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    final chatId = tdInt(update['id']);

    if (extra != null && chatId != null) {
      if (extra.startsWith('newChatPublic_')) {
        _newChatSearchIds = {..._newChatSearchIds, chatId}.toList();
        _newChatSearchPublicIds.add(chatId);
        final requestId =
            int.tryParse(extra.substring('newChatPublic_'.length));
        if (requestId == _newChatSearchRequestId) {
          _completeNewChatSearchRequest();
        }
      } else if (extra == 'chatInfo_chat_$chatId') {
        _mergeChatInfo(
          chatId,
          TdlibChatInfoParser.parseChatForInfo(update, chatId: chatId),
        );
        final chat = _chatsById[chatId] ??
            TdlibChatParser.parseChat(
              update,
              myUserId: _myUserId,
              botUsers: _botUsers,
            );
        if (chat != null) {
          _continueChatInfoLoad(chatId, chat);
        } else {
          _finishChatInfoLoad();
        }
      } else if (_chatActionCompleters.containsKey(extra)) {
        _completeChatAction(extra, chatId);
      }
    }

    _upsertChat(
      TdlibChatParser.parseChat(
        update,
        myUserId: _myUserId,
        botUsers: _botUsers,
      ),
    );
  }

  void _handleCreatedBasicGroupChat(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    final chatId = tdInt(update['chat_id']);
    if (extra == null || chatId == null) {
      return;
    }
    _completeChatAction(extra, chatId);
    _client.send({'@type': 'getChat', 'chat_id': chatId});
  }

  void _handleChatJoinSuccess(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    final chatId = tdInt(update['chat_id']);
    if (extra == null || chatId == null) {
      return;
    }
    _newChatSearchPublicIds.remove(chatId);
    _completeChatAction(extra, chatId);
    _client.send({'@type': 'getChat', 'chat_id': chatId});
  }

  void _handleChatJoinRequestSent(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null) {
      return;
    }
    _failChatAction(extra, 'Заявка на вступление отправлена');
  }

  void _handleChatJoinDeclined(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null) {
      return;
    }
    _failChatAction(extra, 'Не удалось вступить в чат');
  }

  void _completeChatAction(String extra, int chatId) {
    final completer = _chatActionCompleters.remove(extra);
    completer?.complete(chatId);
  }

  void _failChatAction(String extra, String message) {
    final completer = _chatActionCompleters.remove(extra);
    if (completer == null) {
      return;
    }
    _chatActionError = message;
    completer.completeError(StateError(message));
    notifyListeners();
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
    if (extra != null && extra.startsWith('messageThreadHistory_')) {
      _handleMessageThreadHistory(update);
      return;
    }

    if (extra != null && extra.startsWith('forumTopicHistory_')) {
      _handleForumTopicHistory(update, extra);
      return;
    }

    final isLocal = extra?.startsWith('getChatHistoryLocal_') ?? false;
    final chatId = tdInt(update['chat_id']) ??
        _chatIdFromExtra(extra, 'getChatHistoryLocal_') ??
        _chatIdFromExtra(extra, 'getChatHistory_');
    if (chatId == null || chatId != _activeChatId) {
      return;
    }

    final rawMessages = update['messages'] as List<dynamic>? ?? [];
    final parsed = rawMessages
        .whereType<Map<String, dynamic>>()
        .map(_parseMessage)
        .whereType<ChatMessage>()
        .toList();

    // TDLib: reverse chronological → храним oldest→newest.
    parsed.sort((a, b) => a.id.compareTo(b.id));
    final added = _mergeHistoryMessages(parsed);
    if (added > 0) {
      _requestMediaDownloads();
    }
    _historyPagesFetched += 1;

    // Показываем UI сразу по первому батчу; дальше догружаем в фоне.
    if (_isLoadingMessages && (_messages.isNotEmpty || !isLocal)) {
      _isLoadingMessages = false;
      _messagesError = null;
    }

    final shouldContinue = _shouldContinueHistoryLoad(added: added);
    if (shouldContinue) {
      final oldestId = _messages.first.id;
      _requestChatHistory(
        chatId,
        onlyLocal: isLocal,
        fromMessageId: oldestId,
      );
    } else if (!isLocal) {
      _messagesLoadTimeout?.cancel();
      _isLoadingMessages = false;
      _messagesError = null;
      if (_messages.isNotEmpty) {
        _markMessagesRead(chatId, _messages);
      }
    }

    notifyListeners();
  }

  /// Добавляет сообщения истории без потери уже показанных.
  /// Возвращает число новых id.
  int _mergeHistoryMessages(List<ChatMessage> batch) {
    if (batch.isEmpty) {
      return 0;
    }
    final filtered = _securityPrivacy?.shouldBlockAds == true
        ? AdBlockFilter.filterMessages(batch)
        : batch;
    if (filtered.isEmpty) {
      return 0;
    }
    final existingIds = {for (final message in _messages) message.id};
    var added = 0;
    for (final message in filtered) {
      if (existingIds.add(message.id)) {
        _messages.add(message);
        added += 1;
      } else {
        final index = _messages.indexWhere((item) => item.id == message.id);
        if (index >= 0) {
          _messages[index] = message;
        }
      }
    }
    if (added > 0) {
      _messages.sort((a, b) => a.id.compareTo(b.id));
    }
    return added;
  }

  bool _shouldContinueHistoryLoad({required int added}) {
    if (_activeChatId == null || _messages.isEmpty) {
      return false;
    }
    if (_messages.length >= _historyTargetCount) {
      return false;
    }
    if (_historyPagesFetched >= _historyMaxPages) {
      return false;
    }
    // Нет новых сообщений → конец истории (дубликат from_message_id).
    return added > 0;
  }

  void _markMessagesRead(int chatId, List<ChatMessage> messages) {
    if (_ghostMode?.shouldHideReadReceipts == true) {
      return;
    }

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
    final raw = update['message'] as Map<String, dynamic>;
    if (!_messageMatchesActiveForumTopic(raw)) {
      return;
    }
    final message = _parseMessage(raw);
    if (message == null) {
      return;
    }

    _insertMessage(message);
    _appendThreadMessage(message);
    _updateChatPreview(message);
    if (message.chatId == _activeChatId) {
      _maybeStartPendingLiveBroadcast(message);
    }

    if (message.chatId != _activeChatId) {
      final chat = _chatsById[message.chatId];
      final chatTitle = chat?.title ?? 'Новое сообщение';
      final shouldNotify = _notificationSettings?.shouldNotify(
            chatId: message.chatId,
            kind: chat?.kind ?? ChatKind.privateChat,
          ) ??
          !(chat?.isMuted ?? false);
      if (shouldNotify) {
        final body = _notificationSettings?.notificationBody(
              chatId: message.chatId,
              kind: chat?.kind ?? ChatKind.privateChat,
              preview: message.content.preview,
            ) ??
            message.content.preview;
        _notifications.showMessageNotification(
          title: chatTitle,
          body: body,
        );
      }
    }
  }

  void _handleSendSucceeded(Map<String, dynamic> update) {
    final oldMessageId = tdInt(update['old_message_id']);
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
        _maybeStartPendingLiveBroadcast(message);
        notifyListeners();
        return;
      }
    }
    _replaceMessage(message);
    _maybeStartPendingLiveBroadcast(message);
  }

  void _handleMessageEdited(Map<String, dynamic> update) {
    final chatId = tdInt(update['chat_id']);
    final messageId = tdInt(update['message_id']);
    if (chatId != _activeChatId || messageId == null) {
      return;
    }

    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index >= 0 && _isAntiRecallEnabled) {
      unawaited(
        _antiRecallStore?.captureMessage(
          _messages[index],
          reason: AntiRecallSnapshotReason.edited,
        ),
      );
    }

    final editDateSeconds = tdIntOr(update['edit_date']);
    final editDate = editDateSeconds > 0
        ? DateTime.fromMillisecondsSinceEpoch(editDateSeconds * 1000)
        : null;

    if (index >= 0) {
      _messages[index] = _messages[index].copyWith(editDate: editDate);
      notifyListeners();
    }
  }

  void _handleMessageContent(Map<String, dynamic> update) {
    final chatId = tdInt(update['chat_id']);
    final messageId = tdInt(update['message_id']);
    final newContent = update['new_content'] as Map<String, dynamic>?;
    if (chatId != _activeChatId || messageId == null || newContent == null) {
      return;
    }

    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index < 0) {
      return;
    }

    if (_isAntiRecallEnabled) {
      unawaited(
        _antiRecallStore?.captureMessage(
          _messages[index],
          reason: AntiRecallSnapshotReason.edited,
        ),
      );
    }

    final current = _messages[index];
    _messages[index] = current.copyWith(
      content: MessageContent.fromTdlib(
        newContent,
        isOutgoing: current.isOutgoing,
      ),
      mediaFileId:
          MessageContent.parseMediaFileId(newContent) ?? current.mediaFileId,
      coverFileId:
          MessageContent.parseCoverFileId(newContent) ?? current.coverFileId,
    );
    _requestDownloadForMessage(_messages[index]);
    notifyListeners();
  }

  void _handleDeleteMessages(Map<String, dynamic> update) {
    final chatId = tdInt(update['chat_id']);
    if (chatId != _activeChatId) {
      return;
    }

    final ids = (update['message_ids'] as List<dynamic>? ?? []).cast<int>();
    if (ids.isEmpty) {
      return;
    }

    final isPermanent = update['is_permanent'] as bool? ?? true;
    if (isPermanent && _isAntiRecallEnabled) {
      for (final id in ids) {
        final index = _messages.indexWhere((message) => message.id == id);
        if (index < 0) {
          continue;
        }
        final message = _messages[index];
        unawaited(_antiRecallStore?.markDeleted(message));
        _messages[index] = message.copyWith(
          isDeleted: true,
          content: const MessageContent(
            kind: MessageKind.text,
            preview: 'Сообщение удалено отправителем',
          ),
        );
      }
    } else if (isPermanent) {
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
    final chatId = tdInt(update['chat_id']);
    final messageId = tdInt(update['message_id']);
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
    final chatId = tdInt(update['chat_id']);
    final messageId = tdInt(update['message_id']);
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
    final chatId = tdInt(update['chat_id']);
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

    final fileId = tdInt(file['id']);
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
                  stickerInfo: message.content.stickerInfo,
                  animationInfo: message.content.animationInfo,
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
    if (_securityPrivacy?.shouldBlockAds == true &&
        AdBlockFilter.isSponsoredMessage(message)) {
      return;
    }

    if (_isAntiRecallEnabled) {
      unawaited(_antiRecallStore?.captureMessage(message));
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
      lastMessageIsOutgoing: message.isOutgoing,
      lastMessageDeliveryStatus: message.deliveryStatus,
      unreadCount: message.chatId == _activeChatId ? 0 : chat.unreadCount + 1,
    );
    notifyListeners();
  }

  void _requestMediaDownloads() {
    for (final message in _messages) {
      _requestDownloadForMessage(message);
    }
  }

  void _mergeChatInfo(int chatId, ChatDetailInfo patch) {
    final existing = _chatInfoById[chatId] ?? ChatDetailInfo(chatId: chatId);
    final merged = existing.merge(patch);
    _chatInfoById[chatId] = merged;
    _syncChannelSummary(chatId, merged);
  }

  void _syncChannelSummary(int chatId, ChatDetailInfo info) {
    final chat = _chatsById[chatId];
    if (chat?.kind != ChatKind.channel) {
      return;
    }
    _chatsById[chatId] = chat!.copyWith(
      canSendMessages: info.canSendInChannel,
    );
  }

  bool _canPostInChannel(int chatId) {
    final info = _chatInfoById[chatId];
    if (info != null) {
      if (!info.isSubscribed) {
        return false;
      }
      return info.canSendInChannel;
    }
    return _chatsById[chatId]?.canSendMessages ?? false;
  }

  void _continueChatInfoLoad(int chatId, ChatSummary chat) {
    if (_loadingChatInfoForChatId != chatId) {
      return;
    }

    var pending = 0;

    if (chat.basicGroupId != null) {
      pending = 2;
      _client.send({
        '@type': 'getBasicGroupFullInfo',
        'basic_group_id': chat.basicGroupId,
        '@extra': 'chatInfo_basicFull_$chatId',
      });
      _client.send({
        '@type': 'getBasicGroup',
        'basic_group_id': chat.basicGroupId,
        '@extra': 'chatInfo_basic_$chatId',
      });
    } else if (chat.supergroupId != null) {
      // Список участников в каналах (broadcast) недоступен обычным подписчикам —
      // getSupergroupMembers вернёт "Member list is inaccessible".
      final requestMembers = chat.kind != ChatKind.channel;
      pending = requestMembers ? 3 : 2;
      _client.send({
        '@type': 'getSupergroup',
        'supergroup_id': chat.supergroupId,
        '@extra': 'chatInfo_super_$chatId',
      });
      _client.send({
        '@type': 'getSupergroupFullInfo',
        'supergroup_id': chat.supergroupId,
        '@extra': 'chatInfo_superFull_$chatId',
      });
      if (requestMembers) {
        _client.send({
          '@type': 'getSupergroupMembers',
          'supergroup_id': chat.supergroupId,
          'filter': {'@type': 'supergroupMembersFilterRecent'},
          'offset': 0,
          'limit': 50,
          '@extra': 'chatInfo_members_$chatId',
        });
      }
    } else if (chat.privateUserId != null) {
      pending = 1;
      _client.send({
        '@type': 'getUser',
        'user_id': chat.privateUserId,
        '@extra': 'chatInfo_user_$chatId',
      });
    }

    if (pending == 0) {
      _finishChatInfoLoad();
      return;
    }

    _chatInfoPendingRequests = pending;
  }

  void _completeChatInfoRequest() {
    if (_chatInfoPendingRequests <= 0) {
      return;
    }
    _chatInfoPendingRequests -= 1;
    if (_chatInfoPendingRequests == 0) {
      _finishChatInfoLoad();
    }
  }

  void _finishChatInfoLoad() {
    _isLoadingChatInfo = false;
    notifyListeners();
  }

  int? _chatIdFromChatInfoExtra(String? extra, String prefix) {
    if (extra == null || !extra.startsWith(prefix)) {
      return null;
    }
    return int.tryParse(extra.substring(prefix.length));
  }

  void _handleSupergroupResponse(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    final chatId = _chatIdFromChatInfoExtra(extra, 'chatInfo_super_');
    if (chatId == null) {
      return;
    }
    _mergeChatInfo(
      chatId,
      TdlibChatInfoParser.parseSupergroup(update, chatId: chatId),
    );
    _completeChatInfoRequest();
    notifyListeners();
  }

  void _handleSupergroupFullInfoResponse(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    final chatId = _chatIdFromChatInfoExtra(extra, 'chatInfo_superFull_');
    if (chatId == null) {
      return;
    }
    _mergeChatInfo(
      chatId,
      TdlibChatInfoParser.parseSupergroupFullInfo(update, chatId: chatId),
    );
    _completeChatInfoRequest();
    notifyListeners();
  }

  void _handleBasicGroupResponse(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    final chatId = _chatIdFromChatInfoExtra(extra, 'chatInfo_basic_');
    if (chatId == null) {
      return;
    }
    _mergeChatInfo(
      chatId,
      TdlibChatInfoParser.parseBasicGroupMeta(update, chatId: chatId),
    );
    _completeChatInfoRequest();
    notifyListeners();
  }

  void _handleBasicGroupFullInfoResponse(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    final chatId = _chatIdFromChatInfoExtra(extra, 'chatInfo_basicFull_');
    if (chatId == null) {
      return;
    }
    final parsed = TdlibChatInfoParser.parseBasicGroupFullInfo(
      update,
      chatId: chatId,
    );
    _mergeChatInfo(chatId, parsed);
    final members = TdlibChatInfoParser.parseChatMembers({
      '@type': 'chatMembers',
      'total_count': (update['members'] as List<dynamic>? ?? []).length,
      'members': update['members'],
    });
    _storeChatMembers(chatId, members, members.length);
    for (final member in members) {
      _requestUserIfNeeded(member.userId);
    }
    _completeChatInfoRequest();
    notifyListeners();
  }

  void _handleChatMembersResponse(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    final chatId = _chatIdFromChatInfoExtra(extra, 'chatInfo_members_');
    if (chatId == null) {
      return;
    }
    final members = TdlibChatInfoParser.parseChatMembers(update);
    final total = TdlibChatInfoParser.parseChatMembersTotalCount(update) ??
        members.length;
    _storeChatMembers(chatId, members, total);
    for (final member in members) {
      _requestUserIfNeeded(member.userId);
    }
    _completeChatInfoRequest();
    notifyListeners();
  }

  void _handleChatInviteLinkResponse(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    final chatId = _chatIdFromChatInfoExtra(extra, 'chatInfo_createInvite_');
    if (chatId == null) {
      return;
    }
    final link = TdlibChatInfoParser.parseInviteLink(update);
    if (link != null) {
      _mergeChatInfo(
        chatId,
        ChatDetailInfo(chatId: chatId).copyWithInviteLink(link),
      );
      notifyListeners();
    }
  }

  void _handleMessageThreadInfo(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('messageThread_')) {
      return;
    }
    final suffix = extra.substring('messageThread_'.length);
    final separator = suffix.lastIndexOf('_');
    if (separator <= 0) {
      return;
    }
    final channelChatId = int.tryParse(suffix.substring(0, separator));
    final channelMessageId = int.tryParse(suffix.substring(separator + 1));
    if (channelChatId == null || channelMessageId == null) {
      return;
    }

    final context = TdlibChatInfoParser.parseMessageThreadInfo(
      update,
      channelChatId: channelChatId,
      channelMessageId: channelMessageId,
      postPreview: _pendingThreadPreview,
    );
    if (context == null) {
      _isLoadingMessageThread = false;
      _messageThreadError = 'Комментарии недоступны';
      notifyListeners();
      return;
    }

    _messageThreadContext = context;
    final initialMessages = update['messages'] as List<dynamic>? ?? [];
    _messageThreadMessages = initialMessages
        .whereType<Map<String, dynamic>>()
        .map(_parseMessage)
        .whereType<ChatMessage>()
        .toList();
    _isLoadingMessageThread = false;
    _client.send({
      '@type': 'getMessageThreadHistory',
      'chat_id': channelChatId,
      'message_id': channelMessageId,
      'from_message_id': 0,
      'offset': 0,
      'limit': 50,
      '@extra': 'messageThreadHistory_${channelChatId}_$channelMessageId',
    });
    notifyListeners();
  }

  void _handleMessageThreadHistory(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('messageThreadHistory_')) {
      return;
    }
    final messages = (update['messages'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_parseMessage)
        .whereType<ChatMessage>()
        .toList();
    if (messages.isEmpty) {
      return;
    }
    final existingIds = _messageThreadMessages.map((m) => m.id).toSet();
    final merged = [
      ...messages.where((message) => !existingIds.contains(message.id)),
      ..._messageThreadMessages,
    ]..sort((a, b) => a.date.compareTo(b.date));
    _messageThreadMessages = merged;
    notifyListeners();
  }

  void _appendThreadMessage(ChatMessage message) {
    final context = _messageThreadContext;
    if (context == null || message.chatId != context.discussionChatId) {
      return;
    }
    if (_messageThreadMessages.any((item) => item.id == message.id)) {
      return;
    }
    _messageThreadMessages = [..._messageThreadMessages, message]
      ..sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
  }

  void _storeChatMembers(
    int chatId,
    List<ChatMemberInfo> members,
    int totalCount,
  ) {
    _chatMembersById[chatId] = members
        .map(
          (member) => member.copyWithDisplayName(
            _userDisplayNames[member.userId],
          ),
        )
        .toList();
    _chatMembersTotalCount[chatId] = totalCount;
  }

  void _refreshMemberDisplayNames(int userId) {
    final name = _userDisplayNames[userId];
    if (name == null) {
      return;
    }
    var changed = false;
    for (final entry in _chatMembersById.entries) {
      final members = entry.value;
      final updated = members
          .map(
            (member) => member.userId == userId
                ? member.copyWithDisplayName(name)
                : member,
          )
          .toList();
      if (updated != members) {
        _chatMembersById[entry.key] = updated;
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void _requestUserIfNeeded(int userId) {
    if (_userDisplayNames.containsKey(userId)) {
      return;
    }
    _client.send({
      '@type': 'getUser',
      'user_id': userId,
    });
  }

  bool _messageMatchesActiveForumTopic(Map<String, dynamic> json) {
    final activeTopicId = _activeForumTopicId;
    if (activeTopicId == null) {
      return true;
    }
    final topic = json['topic_id'] as Map<String, dynamic>?;
    if (topic?['@type'] != 'messageTopicForum') {
      return false;
    }
    return topic?['forum_topic_id'] == activeTopicId;
  }

  void _handleForumTopics(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null ||
        (!extra.startsWith('forumTopics_') &&
            !extra.startsWith('forumTopicsMore_'))) {
      return;
    }
    final prefix = extra.startsWith('forumTopicsMore_')
        ? 'forumTopicsMore_'
        : 'forumTopics_';
    final chatId = int.tryParse(extra.substring(prefix.length));
    if (chatId == null || chatId != _loadingForumTopicsForChatId) {
      return;
    }

    final topics = TdlibForumParser.parseForumTopics(update);
    final existing = _forumTopicsByChatId[chatId] ?? [];
    final mergedIds = existing.map((topic) => topic.forumTopicId).toSet();
    _forumTopicsByChatId[chatId] = [
      ...existing,
      ...topics.where((topic) => !mergedIds.contains(topic.forumTopicId)),
    ]..sort((a, b) => b.order.compareTo(a.order));
    _forumTopicsTotalCount[chatId] =
        TdlibForumParser.parseForumTopicsTotalCount(update) ??
            _forumTopicsByChatId[chatId]!.length;
    _forumTopicsNextOffset = TdlibForumParser.parseForumTopicsOffset(update);
    _isLoadingForumTopics = false;
    notifyListeners();
  }

  void _handleForumTopicInfo(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('createForumTopic_')) {
      return;
    }
    final chatId = int.tryParse(extra.substring('createForumTopic_'.length));
    if (chatId == null) {
      return;
    }
    final created = TdlibForumParser.parseForumTopicInfo(update);
    if (created == null) {
      return;
    }
    final existing = _forumTopicsByChatId[chatId] ?? [];
    if (existing.any((topic) => topic.forumTopicId == created.forumTopicId)) {
      loadForumTopics(chatId);
      return;
    }
    _forumTopicsByChatId[chatId] = [created, ...existing]
      ..sort((a, b) => b.order.compareTo(a.order));
    notifyListeners();
  }

  void _handleForumTopicHistory(Map<String, dynamic> update, String extra) {
    final prefix = 'forumTopicHistory_';
    final suffix = extra.substring(prefix.length);
    final separator = suffix.lastIndexOf('_');
    if (separator <= 0) {
      return;
    }
    final chatId = int.tryParse(suffix.substring(0, separator));
    final forumTopicId = int.tryParse(suffix.substring(separator + 1));
    if (chatId == null ||
        forumTopicId == null ||
        chatId != _activeChatId ||
        forumTopicId != _activeForumTopicId) {
      return;
    }

    final rawMessages = update['messages'] as List<dynamic>? ?? [];
    final parsed = rawMessages
        .whereType<Map<String, dynamic>>()
        .where(_messageMatchesActiveForumTopic)
        .map(_parseMessage)
        .whereType<ChatMessage>()
        .toList();
    parsed.sort((a, b) => a.id.compareTo(b.id));

    final added = _mergeHistoryMessages(parsed);
    if (added > 0) {
      _requestMediaDownloads();
    }
    _historyPagesFetched += 1;

    if (_isLoadingMessages && _messages.isNotEmpty) {
      _isLoadingMessages = false;
      _messagesError = null;
    }

    if (_shouldContinueHistoryLoad(added: added)) {
      _requestForumTopicHistory(
        chatId,
        forumTopicId,
        fromMessageId: _messages.first.id,
      );
    } else {
      _messagesLoadTimeout?.cancel();
      _isLoadingMessages = false;
      _messagesError = null;
      if (_messages.isNotEmpty) {
        _markMessagesRead(chatId, _messages);
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _liveLocationTracker.stop();
    _messagesLoadTimeout?.cancel();
    _searchDebounce?.cancel();
    _newChatSearchDebounce?.cancel();
    _typingStatusClearTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
