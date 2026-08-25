import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/user_models.dart';
import '../chat/tdlib_chat_parser.dart';
import '../tdlib/tdlib_client.dart';
import '../tdlib/tdlib_json.dart';
import 'tdlib_user_parser.dart';
import 'user_status_formatter.dart';

/// Профиль пользователя, блокировка и статусы онлайн.
class ProfileManager extends ChangeNotifier {
  ProfileManager({required TdlibClient client}) : _client = client;

  final TdlibClient _client;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  OwnProfileDraft? _ownProfile;
  UserSummary? _ownUser;
  final Map<int, UserSummary> _usersById = {};
  final Map<int, UserProfileFullInfo> _fullInfoByUserId = {};
  final Map<int, List<CommonChatSummary>> _commonChatsByUserId = {};
  final List<BlockedUserSummary> _blockedUsers = [];

  var _isLoadingOwn = false;
  var _isSavingOwn = false;
  var _isLoadingBlocked = false;
  final Set<int> _loadingFullInfo = {};
  final Set<int> _loadingCommonChats = {};
  String? _lastError;

  OwnProfileDraft? get ownProfile => _ownProfile;
  UserSummary? get ownUser => _ownUser;
  List<BlockedUserSummary> get blockedUsers => List.unmodifiable(_blockedUsers);
  bool get isLoadingOwn => _isLoadingOwn;
  bool get isSavingOwn => _isSavingOwn;
  bool get isLoadingBlocked => _isLoadingBlocked;
  String? get lastError => _lastError;

  UserSummary? userById(int userId) => _usersById[userId];

  UserProfileFullInfo? fullInfoFor(int userId) => _fullInfoByUserId[userId];

  List<CommonChatSummary> commonChatsFor(int userId) =>
      _commonChatsByUserId[userId] ?? const [];

  bool isLoadingFullInfo(int userId) => _loadingFullInfo.contains(userId);

  bool isLoadingCommonChats(int userId) => _loadingCommonChats.contains(userId);

  String statusTextFor(int userId) {
    final user = _usersById[userId];
    if (user == null) {
      return '';
    }
    return UserStatusFormatter.format(user.status);
  }

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void loadOwnProfile() {
    _isLoadingOwn = true;
    _lastError = null;
    notifyListeners();
    _client.send({
      '@type': 'getMe',
      '@extra': 'profile_own_me',
    });
  }

  void loadUserProfile(int userId) {
    _loadingFullInfo.add(userId);
    notifyListeners();
    _client.send({
      '@type': 'getUser',
      'user_id': userId,
      '@extra': 'profile_user_$userId',
    });
    _client.send({
      '@type': 'getUserFullInfo',
      'user_id': userId,
      '@extra': 'profile_full_$userId',
    });
  }

  void loadCommonChats(int userId) {
    _loadingCommonChats.add(userId);
    notifyListeners();
    _client.send({
      '@type': 'getGroupsInCommon',
      'user_id': userId,
      'offset_chat_id': 0,
      'limit': 50,
      '@extra': 'profile_common_$userId',
    });
  }

  void loadBlockedUsers() {
    _isLoadingBlocked = true;
    _lastError = null;
    notifyListeners();
    _client.send({
      '@type': 'getBlockedMessageSenders',
      'block_list': {'@type': 'blockListMain'},
      'offset': 0,
      'limit': 100,
      '@extra': 'profile_blocked',
    });
  }

  void setName({required String firstName, required String lastName}) {
    _isSavingOwn = true;
    notifyListeners();
    _client.send({
      '@type': 'setName',
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      '@extra': 'profile_set_name',
    });
  }

  void setBio(String bio) {
    _isSavingOwn = true;
    notifyListeners();
    _client.send({
      '@type': 'setBio',
      'bio': bio.trim(),
      '@extra': 'profile_set_bio',
    });
  }

  void setUsername(String username) {
    _isSavingOwn = true;
    notifyListeners();
    _client.send({
      '@type': 'setUsername',
      'username': username.trim(),
      '@extra': 'profile_set_username',
    });
  }

  void setProfilePhoto(String localPath) {
    _isSavingOwn = true;
    notifyListeners();
    _client.send({
      '@type': 'setProfilePhoto',
      'photo': {
        '@type': 'inputChatPhotoStatic',
        'photo': {
          '@type': 'inputFileLocal',
          'path': localPath,
        },
      },
      'is_public': true,
      '@extra': 'profile_set_photo',
    });
  }

  void blockUser(int userId) {
    _client.send({
      '@type': 'setMessageSenderBlockList',
      'sender_id': {
        '@type': 'messageSenderUser',
        'user_id': userId,
      },
      'block_list': {'@type': 'blockListMain'},
      '@extra': 'profile_block_$userId',
    });
    _fullInfoByUserId[userId] = UserProfileFullInfo(
      userId: userId,
      bio: _fullInfoByUserId[userId]?.bio ?? '',
      isBlocked: true,
      canBeCalled: false,
      supportsVideoCalls: false,
      groupInCommonCount: _fullInfoByUserId[userId]?.groupInCommonCount ?? 0,
      personalChatId: _fullInfoByUserId[userId]?.personalChatId,
    );
    notifyListeners();
  }

  void unblockUser(int userId) {
    _client.send({
      '@type': 'setMessageSenderBlockList',
      'sender_id': {
        '@type': 'messageSenderUser',
        'user_id': userId,
      },
      'block_list': null,
      '@extra': 'profile_unblock_$userId',
    });
    _blockedUsers.removeWhere((entry) => entry.userId == userId);
    final existing = _fullInfoByUserId[userId];
    if (existing != null) {
      _fullInfoByUserId[userId] = UserProfileFullInfo(
        userId: userId,
        bio: existing.bio,
        isBlocked: false,
        canBeCalled: existing.canBeCalled,
        supportsVideoCalls: existing.supportsVideoCalls,
        groupInCommonCount: existing.groupInCommonCount,
        personalChatId: existing.personalChatId,
      );
    }
    notifyListeners();
  }

  void blockFromReplies(
    int messageId, {
    bool deleteMessage = false,
    bool deleteAllMessages = false,
    bool reportSpam = false,
  }) {
    _client.send({
      '@type': 'blockMessageSenderFromReplies',
      'message_id': messageId,
      'delete_message': deleteMessage,
      'delete_all_messages': deleteAllMessages,
      'report_spam': reportSpam,
      '@extra': 'profile_block_replies_$messageId',
    });
  }

  void _handleUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case 'user':
        _handleUser(update);
      case 'userFullInfo':
        _handleUserFullInfo(update);
      case 'users':
        _handleUsers(update);
      case 'chats':
        _handleChats(update);
      case 'chat':
        _handleChat(update);
      case 'messageSenders':
        _handleBlockedSenders(update);
      case 'file':
        _handleFile(update);
      case 'updateUserStatus':
        _handleUpdateUserStatus(update);
      case 'updateUserFullInfo':
        _handleUpdateUserFullInfo(update);
      case 'updateUser':
        _handleUser(update['user'] as Map<String, dynamic>);
      case 'ok':
        _handleOk(update);
      case 'error':
        _handleError(update);
    }
  }

  void _handleUser(Map<String, dynamic> update) {
    final user = _parseAndCacheUser(update);
    if (user == null) {
      return;
    }

    final extra = update['@extra'] as String?;
    if (extra == 'profile_own_me' || (update['is_self'] as bool? ?? false)) {
      _ownUser = user;
      _client.send({
        '@type': 'getUserFullInfo',
        'user_id': user.id,
        '@extra': 'profile_own_full',
      });
    }

    if (extra?.startsWith('profile_user_') == true ||
        extra?.startsWith('profile_blocked_user_') == true) {
      _loadingFullInfo.remove(user.id);
      notifyListeners();
    }
  }

  void _handleUserFullInfo(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('profile_')) {
      return;
    }

    final userId = _userIdFromExtra(extra);
    if (userId == null) {
      return;
    }

    final info = TdlibUserParser.parseUserFullInfo(
      update,
      userId: userId,
    );
    if (info == null) {
      return;
    }

    _fullInfoByUserId[userId] = info;
    _loadingFullInfo.remove(userId);

    if (extra == 'profile_own_full') {
      final user = _ownUser;
      if (user != null) {
        _ownProfile = OwnProfileDraft(
          userId: user.id,
          firstName: user.firstName,
          lastName: user.lastName,
          username: user.username ?? '',
          bio: info.bio,
          avatarLocalPath: user.avatarLocalPath,
        );
      }
      _isLoadingOwn = false;
    }

    notifyListeners();
  }

  void _handleUsers(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra != 'profile_blocked') {
      return;
    }

    final userIds = TdlibUserParser.parseUserIds(update);
    for (final userId in userIds) {
      _client.send({
        '@type': 'getUser',
        'user_id': userId,
        '@extra': 'profile_blocked_user_$userId',
      });
    }
  }

  void _handleChats(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('profile_common_')) {
      return;
    }

    final userId = int.tryParse(extra.substring('profile_common_'.length));
    if (userId == null) {
      return;
    }

    final chats = TdlibUserParser.parseCommonChats(update);
    _commonChatsByUserId[userId] = chats;
    _loadingCommonChats.remove(userId);

    for (final chat in chats) {
      _client.send({
        '@type': 'getChat',
        'chat_id': chat.id,
        '@extra': 'profile_common_chat_${userId}_${chat.id}',
      });
    }
    notifyListeners();
  }

  void _handleChat(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('profile_common_chat_')) {
      return;
    }

    final parts = extra.split('_');
    if (parts.length < 5) {
      return;
    }
    final userId = int.tryParse(parts[3]);
    final chatId = int.tryParse(parts[4]);
    final title = update['title'] as String?;
    if (userId == null || chatId == null || title == null) {
      return;
    }

    final list = _commonChatsByUserId[userId];
    if (list == null) {
      return;
    }

    _commonChatsByUserId[userId] = list
        .map(
          (chat) => chat.id == chatId
              ? CommonChatSummary(id: chat.id, title: title)
              : chat,
        )
        .toList();
    notifyListeners();
  }

  void _handleBlockedSenders(Map<String, dynamic> update) {
    if (update['@extra'] != 'profile_blocked') {
      return;
    }

    final blocked = TdlibUserParser.parseBlockedSenders(update);
    _blockedUsers
      ..clear()
      ..addAll(blocked);
    _isLoadingBlocked = false;

    for (final entry in blocked) {
      final user = _usersById[entry.userId];
      _blockedUsers[_blockedUsers.indexWhere((b) => b.userId == entry.userId)] =
          BlockedUserSummary(
        userId: entry.userId,
        displayName: user?.displayName,
      );
      if (user == null) {
        _client.send({
          '@type': 'getUser',
          'user_id': entry.userId,
          '@extra': 'profile_blocked_user_${entry.userId}',
        });
      }
    }
    notifyListeners();
  }

  void _handleFile(Map<String, dynamic> update) {
    final local = update['local'] as Map<String, dynamic>?;
    if (local == null || local['is_downloading_completed'] != true) {
      return;
    }
    final localPath = local['path'] as String?;
    final fileId = tdInt(update['id']);
    if (localPath == null || fileId == null) {
      return;
    }

    var changed = false;
    for (final entry in _usersById.entries.toList()) {
      if (entry.value.avatarFileId == fileId &&
          entry.value.avatarLocalPath != localPath) {
        _usersById[entry.key] =
            entry.value.copyWith(avatarLocalPath: localPath);
        if (_ownUser?.id == entry.key) {
          _ownUser = _usersById[entry.key];
          final draft = _ownProfile;
          if (draft != null) {
            _ownProfile = OwnProfileDraft(
              userId: draft.userId,
              firstName: draft.firstName,
              lastName: draft.lastName,
              username: draft.username,
              bio: draft.bio,
              avatarLocalPath: localPath,
            );
          }
        }
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void _handleUpdateUserStatus(Map<String, dynamic> update) {
    final userId = tdIntOr(update['user_id']);
    final status = TdlibUserParser.parseUserStatus(
      update['status'] as Map<String, dynamic>?,
    );
    _applyStatus(userId, status);
  }

  void _handleUpdateUserFullInfo(Map<String, dynamic> update) {
    final userId = tdIntOr(update['user_id']);
    final info = TdlibUserParser.parseUserFullInfo(
      update['user_full_info'] as Map<String, dynamic>?,
      userId: userId,
    );
    if (info == null) {
      return;
    }
    _fullInfoByUserId[userId] = info;
    if (_ownUser?.id == userId) {
      final user = _ownUser!;
      _ownProfile = OwnProfileDraft(
        userId: user.id,
        firstName: user.firstName,
        lastName: user.lastName,
        username: user.username ?? '',
        bio: info.bio,
        avatarLocalPath: user.avatarLocalPath,
      );
    }
    notifyListeners();
  }

  void _handleOk(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('profile_')) {
      return;
    }

    if (extra.startsWith('profile_set_')) {
      _isSavingOwn = false;
      loadOwnProfile();
    } else if (extra.startsWith('profile_block_') ||
        extra.startsWith('profile_unblock_')) {
      loadBlockedUsers();
    }
    notifyListeners();
  }

  void _handleError(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('profile_')) {
      return;
    }
    _lastError = update['message'] as String? ?? 'Ошибка профиля';
    _isLoadingOwn = false;
    _isSavingOwn = false;
    _isLoadingBlocked = false;
    _loadingFullInfo.clear();
    _loadingCommonChats.clear();
    notifyListeners();
  }

  UserSummary? _parseAndCacheUser(Map<String, dynamic> update) {
    final user = TdlibUserParser.parseUser(update);
    if (user == null) {
      return null;
    }

    final avatar = TdlibChatParser.parseAvatar(
      update['profile_photo'] as Map<String, dynamic>?,
    );
    final merged = user.copyWith(
      avatarFileId: avatar.fileId,
      avatarLocalPath: avatar.localPath,
    );
    _usersById[merged.id] = merged;
    _requestAvatarDownload(merged.avatarFileId, merged.avatarLocalPath);

    for (var i = 0; i < _blockedUsers.length; i++) {
      if (_blockedUsers[i].userId == merged.id) {
        _blockedUsers[i] = BlockedUserSummary(
          userId: merged.id,
          displayName: merged.displayName,
        );
      }
    }

    notifyListeners();
    return merged;
  }

  void _applyStatus(int userId, UserStatusInfo status) {
    final user = _usersById[userId];
    if (user == null) {
      return;
    }
    _usersById[userId] = user.copyWith(status: status);
    if (_ownUser?.id == userId) {
      _ownUser = _usersById[userId];
    }
    notifyListeners();
  }

  void _requestAvatarDownload(int? fileId, String? localPath) {
    if (fileId == null || (localPath != null && localPath.isNotEmpty)) {
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

  int? _userIdFromExtra(String extra) {
    if (extra == 'profile_own_full') {
      return _ownUser?.id;
    }
    final match = RegExp(r'profile_(?:full|user|common)_(\d+)').firstMatch(extra);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }
}
