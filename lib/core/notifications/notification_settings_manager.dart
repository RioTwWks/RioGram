import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/chat_models.dart';
import '../../models/notification_settings_models.dart';
import '../tdlib/tdlib_client.dart';
import '../tdlib/tdlib_json.dart';
import 'tdlib_notification_parser.dart';

/// Глобальные и per-chat настройки уведомлений, badge и автоудаление.
class NotificationSettingsManager extends ChangeNotifier {
  NotificationSettingsManager({
    required TdlibClient client,
    void Function(int count)? onBadgeCountChanged,
  })  : _client = client,
        _onBadgeCountChanged = onBadgeCountChanged;

  final TdlibClient _client;
  final void Function(int count)? _onBadgeCountChanged;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  final Map<NotificationScopeKind, ScopeNotificationSettingsModel>
      _scopeSettings = {};
  final Map<int, ChatNotificationSettingsModel> _chatSettings = {};
  final Map<int, int> _chatAutoDeleteSeconds = {};

  AutoDeletePreset _defaultAutoDelete = AutoDeletePreset.off;
  UnreadBadgeState _badgeState = const UnreadBadgeState();
  var _isLoadingScopes = false;
  var _isSaving = false;
  String? _lastError;

  Map<NotificationScopeKind, ScopeNotificationSettingsModel> get scopeSettings =>
      Map.unmodifiable(_scopeSettings);
  UnreadBadgeState get badgeState => _badgeState;
  int get badgeCount => _badgeState.unreadUnmutedCount;
  AutoDeletePreset get defaultAutoDelete => _defaultAutoDelete;
  bool get isLoadingScopes => _isLoadingScopes;
  bool get isSaving => _isSaving;
  String? get lastError => _lastError;

  ChatNotificationSettingsModel? chatSettingsFor(int chatId) =>
      _chatSettings[chatId];

  int autoDeleteSecondsFor(int chatId) => _chatAutoDeleteSeconds[chatId] ?? 0;

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
    loadScopeSettings();
    loadDefaultAutoDelete();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void loadScopeSettings() {
    _isLoadingScopes = true;
    _lastError = null;
    notifyListeners();

    for (final scope in NotificationScopeKind.values) {
      _client.send({
        '@type': 'getScopeNotificationSettings',
        'scope': scope.toTdlib(),
        '@extra': 'notif_scope_${scope.name}',
      });
    }
  }

  void loadDefaultAutoDelete() {
    _client.send({
      '@type': 'getDefaultMessageAutoDeleteTime',
      '@extra': 'notif_default_autodelete',
    });
  }

  void loadChatSettings(int chatId) {
    _client.send({
      '@type': 'getChat',
      'chat_id': chatId,
      '@extra': 'notif_chat_$chatId',
    });
  }

  void setScopeSettings(
    NotificationScopeKind scope,
    ScopeNotificationSettingsModel settings,
  ) {
    _isSaving = true;
    _lastError = null;
    notifyListeners();

    final previous = _scopeSettings[scope];
    _client.send({
      '@type': 'setScopeNotificationSettings',
      'scope': scope.toTdlib(),
      'notification_settings': settings.toTdlib(previous: previous),
      '@extra': 'notif_set_scope_${scope.name}',
    });
  }

  void setScopeMuted(NotificationScopeKind scope, {required bool muted}) {
    final current = _scopeSettings[scope] ?? const ScopeNotificationSettingsModel();
    setScopeSettings(
      scope,
      current.copyWith(
        muteFor: muted ? notificationMuteForeverSeconds : 0,
      ),
    );
  }

  void setScopeShowPreview(
    NotificationScopeKind scope, {
    required bool showPreview,
  }) {
    final current = _scopeSettings[scope] ?? const ScopeNotificationSettingsModel();
    setScopeSettings(
      scope,
      current.copyWith(showPreview: showPreview),
    );
  }

  void setChatSettings(int chatId, ChatNotificationSettingsModel settings) {
    _isSaving = true;
    _lastError = null;
    notifyListeners();

    _client.send({
      '@type': 'setChatNotificationSettings',
      'chat_id': chatId,
      'notification_settings': settings.toTdlib(
        previous: _chatSettings[chatId],
      ),
      '@extra': 'notif_set_chat_$chatId',
    });
  }

  void muteChat(int chatId, {int durationSeconds = notificationMuteForeverSeconds}) {
    final current = _chatSettings[chatId] ?? const ChatNotificationSettingsModel();
    setChatSettings(
      chatId,
      current.copyWith(
        useDefaultMuteFor: false,
        muteFor: durationSeconds,
      ),
    );
  }

  void unmuteChat(int chatId) {
    final current = _chatSettings[chatId] ?? const ChatNotificationSettingsModel();
    setChatSettings(
      chatId,
      current.copyWith(
        useDefaultMuteFor: true,
        muteFor: 0,
      ),
    );
  }

  void setChatShowPreview(int chatId, {required bool showPreview}) {
    final current = _chatSettings[chatId] ?? const ChatNotificationSettingsModel();
    setChatSettings(
      chatId,
      current.copyWith(
        useDefaultShowPreview: false,
        showPreview: showPreview,
      ),
    );
  }

  void setDefaultAutoDelete(AutoDeletePreset preset) {
    _isSaving = true;
    _lastError = null;
    notifyListeners();
    _client.send({
      '@type': 'setDefaultMessageAutoDeleteTime',
      'message_auto_delete_time': {
        '@type': 'messageAutoDeleteTime',
        'time': preset.seconds,
      },
      '@extra': 'notif_set_default_autodelete',
    });
  }

  void setChatAutoDelete(int chatId, AutoDeletePreset preset) {
    _isSaving = true;
    _lastError = null;
    notifyListeners();
    _client.send({
      '@type': 'setChatMessageAutoDeleteTime',
      'chat_id': chatId,
      'message_auto_delete_time': preset.seconds,
      '@extra': 'notif_set_chat_autodelete_$chatId',
    });
    _chatAutoDeleteSeconds[chatId] = preset.seconds;
  }

  bool shouldNotify({
    required int chatId,
    required ChatKind kind,
    bool isMention = false,
  }) {
    final chatSettings = _chatSettings[chatId];
    final scope = TdlibNotificationParser.scopeForChatKind(kind);
    final scopeSettings = _scopeSettings[scope];

    if (chatSettings?.isMuted(scope: scopeSettings) ?? scopeSettings?.isMuted ?? false) {
      return false;
    }

    if (isMention && (scopeSettings?.disableMentionNotifications ?? false)) {
      return false;
    }

    return true;
  }

  String notificationBody({
    required int chatId,
    required ChatKind kind,
    required String preview,
  }) {
    final chatSettings = _chatSettings[chatId];
    final scope = TdlibNotificationParser.scopeForChatKind(kind);
    final scopeSettings = _scopeSettings[scope];
    final showPreview =
        chatSettings?.effectiveShowPreview(scope: scopeSettings) ?? true;
    return showPreview ? preview : 'Новое сообщение';
  }

  void _handleUpdate(Map<String, dynamic> update) {
    final type = update['@type'];
    switch (type) {
      case 'scopeNotificationSettings':
        _handleScopeResponse(update);
      case 'messageAutoDeleteTime':
        _handleDefaultAutoDeleteResponse(update);
      case 'chat':
        _handleChatResponse(update);
      case 'updateScopeNotificationSettings':
        _handleScopeUpdate(update);
      case 'updateChatNotificationSettings':
        _handleChatNotificationUpdate(update);
      case 'updateUnreadMessageCount':
        _handleUnreadBadge(update);
      case 'ok':
        _handleOk(update);
      case 'error':
        _handleError(update);
    }
  }

  void _handleScopeResponse(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('notif_scope_')) {
      return;
    }
    final scopeName = extra.substring('notif_scope_'.length);
    final scope = NotificationScopeKind.values.cast<NotificationScopeKind?>().firstWhere(
          (item) => item?.name == scopeName,
          orElse: () => null,
        );
    if (scope == null) {
      return;
    }

    _scopeSettings[scope] =
        TdlibNotificationParser.parseScopeNotificationSettings(update);
    _isLoadingScopes = _scopeSettings.length < NotificationScopeKind.values.length;
    notifyListeners();
  }

  void _handleScopeUpdate(Map<String, dynamic> update) {
    final scope = TdlibNotificationParser.parseScopeKind(
      update['scope'] as Map<String, dynamic>?,
    );
    final settings = update['notification_settings'] as Map<String, dynamic>?;
    if (scope == null || settings == null) {
      return;
    }
    _scopeSettings[scope] =
        TdlibNotificationParser.parseScopeNotificationSettings(settings);
    notifyListeners();
  }

  void _handleChatResponse(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('notif_chat_')) {
      return;
    }
    final chatId = int.tryParse(extra.substring('notif_chat_'.length));
    if (chatId == null) {
      return;
    }

    final settings =
        update['notification_settings'] as Map<String, dynamic>?;
    if (settings != null) {
      _chatSettings[chatId] =
          TdlibNotificationParser.parseChatNotificationSettings(settings);
    }
    _chatAutoDeleteSeconds[chatId] =
        tdIntOr(update['message_auto_delete_time']);
    notifyListeners();
  }

  void _handleChatNotificationUpdate(Map<String, dynamic> update) {
    final chatId = tdInt(update['chat_id']);
    final settings = update['notification_settings'] as Map<String, dynamic>?;
    if (chatId == null || settings == null) {
      return;
    }
    _chatSettings[chatId] =
        TdlibNotificationParser.parseChatNotificationSettings(settings);
    notifyListeners();
  }

  void _handleDefaultAutoDeleteResponse(Map<String, dynamic> update) {
    if (update['@extra'] != 'notif_default_autodelete') {
      return;
    }
    _defaultAutoDelete = AutoDeletePresetX.fromSeconds(
      NotificationSettingsJson.parseDefaultAutoDeleteSeconds(update),
    );
    notifyListeners();
  }

  void _handleUnreadBadge(Map<String, dynamic> update) {
    _badgeState = NotificationSettingsJson.parseUnreadBadge(update);
    _onBadgeCountChanged?.call(_badgeState.unreadUnmutedCount);
    notifyListeners();
  }

  void _handleOk(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('notif_')) {
      return;
    }
    _isSaving = false;
    if (extra == 'notif_set_default_autodelete') {
      loadDefaultAutoDelete();
    }
    notifyListeners();
  }

  void _handleError(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('notif_')) {
      return;
    }
    _isSaving = false;
    _isLoadingScopes = false;
    _lastError = update['message'] as String? ?? 'Ошибка настроек уведомлений';
    notifyListeners();
  }
}
