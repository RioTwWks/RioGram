import '../core/tdlib/tdlib_json.dart';

/// Область глобальных настроек уведомлений TDLib.
enum NotificationScopeKind {
  privateChats,
  groupChats,
  channelChats,
}

extension NotificationScopeKindX on NotificationScopeKind {
  Map<String, dynamic> toTdlib() {
    return switch (this) {
      NotificationScopeKind.privateChats => {
          '@type': 'notificationSettingsScopePrivateChats',
        },
      NotificationScopeKind.groupChats => {
          '@type': 'notificationSettingsScopeGroupChats',
        },
      NotificationScopeKind.channelChats => {
          '@type': 'notificationSettingsScopeChannelChats',
        },
    };
  }

  String get label => switch (this) {
        NotificationScopeKind.privateChats => 'Личные чаты',
        NotificationScopeKind.groupChats => 'Группы',
        NotificationScopeKind.channelChats => 'Каналы',
      };

  static NotificationScopeKind? fromTdlib(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return switch (json['@type']) {
      'notificationSettingsScopePrivateChats' =>
        NotificationScopeKind.privateChats,
      'notificationSettingsScopeGroupChats' => NotificationScopeKind.groupChats,
      'notificationSettingsScopeChannelChats' =>
        NotificationScopeKind.channelChats,
      _ => null,
    };
  }
}

/// TDLib трактует большие значения mute_for как «навсегда».
const int notificationMuteForeverSeconds = 366 * 86400;

/// Глобальные настройки уведомлений для области чатов.
class ScopeNotificationSettingsModel {
  const ScopeNotificationSettingsModel({
    this.muteFor = 0,
    this.showPreview = true,
    this.disableMentionNotifications = false,
    this.disablePinnedMessageNotifications = false,
  });

  final int muteFor;
  final bool showPreview;
  final bool disableMentionNotifications;
  final bool disablePinnedMessageNotifications;

  bool get isMuted => muteFor > 0;

  ScopeNotificationSettingsModel copyWith({
    int? muteFor,
    bool? showPreview,
    bool? disableMentionNotifications,
    bool? disablePinnedMessageNotifications,
  }) {
    return ScopeNotificationSettingsModel(
      muteFor: muteFor ?? this.muteFor,
      showPreview: showPreview ?? this.showPreview,
      disableMentionNotifications:
          disableMentionNotifications ?? this.disableMentionNotifications,
      disablePinnedMessageNotifications: disablePinnedMessageNotifications ??
          this.disablePinnedMessageNotifications,
    );
  }

  Map<String, dynamic> toTdlib({
    ScopeNotificationSettingsModel? previous,
  }) {
    final prev = previous ?? this;
    return {
      '@type': 'scopeNotificationSettings',
      'mute_for': muteFor,
      'sound_id': 0,
      'show_preview': showPreview,
      'use_default_mute_stories': true,
      'mute_stories': prev.muteFor > 0,
      'story_sound_id': 0,
      'show_story_poster': true,
      'disable_pinned_message_notifications':
          disablePinnedMessageNotifications,
      'disable_mention_notifications': disableMentionNotifications,
    };
  }
}

/// Настройки уведомлений конкретного чата.
class ChatNotificationSettingsModel {
  const ChatNotificationSettingsModel({
    this.useDefaultMuteFor = true,
    this.muteFor = 0,
    this.useDefaultShowPreview = true,
    this.showPreview = true,
    this.useDefaultSound = true,
    this.soundId = 0,
  });

  final bool useDefaultMuteFor;
  final int muteFor;
  final bool useDefaultShowPreview;
  final bool showPreview;
  final bool useDefaultSound;
  final int soundId;

  bool isMuted({ScopeNotificationSettingsModel? scope}) {
    if (useDefaultMuteFor) {
      return scope?.isMuted ?? false;
    }
    return muteFor > 0;
  }

  bool effectiveShowPreview({ScopeNotificationSettingsModel? scope}) {
    if (useDefaultShowPreview) {
      return scope?.showPreview ?? true;
    }
    return showPreview;
  }

  ChatNotificationSettingsModel copyWith({
    bool? useDefaultMuteFor,
    int? muteFor,
    bool? useDefaultShowPreview,
    bool? showPreview,
    bool? useDefaultSound,
    int? soundId,
  }) {
    return ChatNotificationSettingsModel(
      useDefaultMuteFor: useDefaultMuteFor ?? this.useDefaultMuteFor,
      muteFor: muteFor ?? this.muteFor,
      useDefaultShowPreview:
          useDefaultShowPreview ?? this.useDefaultShowPreview,
      showPreview: showPreview ?? this.showPreview,
      useDefaultSound: useDefaultSound ?? this.useDefaultSound,
      soundId: soundId ?? this.soundId,
    );
  }

  Map<String, dynamic> toTdlib({ChatNotificationSettingsModel? previous}) {
    final prev = previous ?? this;
    return {
      '@type': 'chatNotificationSettings',
      'use_default_mute_for': useDefaultMuteFor,
      'mute_for': muteFor,
      'use_default_sound': useDefaultSound,
      'sound_id': soundId,
      'use_default_show_preview': useDefaultShowPreview,
      'show_preview': showPreview,
      'use_default_mute_stories': true,
      'mute_stories': prev.muteFor > 0,
      'use_default_story_sound': true,
      'story_sound_id': 0,
      'use_default_show_story_poster': true,
      'show_story_poster': true,
      'use_default_disable_pinned_message_notifications': true,
      'disable_pinned_message_notifications': false,
      'use_default_disable_mention_notifications': true,
      'disable_mention_notifications': false,
    };
  }
}

/// Предустановки автоудаления сообщений.
enum AutoDeletePreset {
  off,
  oneDay,
  oneWeek,
  oneMonth,
}

extension AutoDeletePresetX on AutoDeletePreset {
  int get seconds => switch (this) {
        AutoDeletePreset.off => 0,
        AutoDeletePreset.oneDay => 86400,
        AutoDeletePreset.oneWeek => 604800,
        AutoDeletePreset.oneMonth => 2592000,
      };

  String get label => switch (this) {
        AutoDeletePreset.off => 'Выкл.',
        AutoDeletePreset.oneDay => '1 день',
        AutoDeletePreset.oneWeek => '1 неделя',
        AutoDeletePreset.oneMonth => '1 месяц',
      };

  static AutoDeletePreset fromSeconds(int seconds) {
    return switch (seconds) {
      <= 0 => AutoDeletePreset.off,
      >= 2592000 => AutoDeletePreset.oneMonth,
      >= 604800 => AutoDeletePreset.oneWeek,
      >= 86400 => AutoDeletePreset.oneDay,
      _ => AutoDeletePreset.off,
    };
  }
}

/// Состояние счётчика непрочитанных для badge.
class UnreadBadgeState {
  const UnreadBadgeState({
    this.unreadCount = 0,
    this.unreadUnmutedCount = 0,
  });

  final int unreadCount;
  final int unreadUnmutedCount;
}

/// Парсинг настроек уведомлений из TDLib JSON.
class NotificationSettingsJson {
  static ScopeNotificationSettingsModel parseScope(Map<String, dynamic> json) {
    return ScopeNotificationSettingsModel(
      muteFor: tdIntOr(json['mute_for']),
      showPreview: json['show_preview'] as bool? ?? true,
      disableMentionNotifications:
          json['disable_mention_notifications'] as bool? ?? false,
      disablePinnedMessageNotifications:
          json['disable_pinned_message_notifications'] as bool? ?? false,
    );
  }

  static ChatNotificationSettingsModel parseChat(Map<String, dynamic> json) {
    return ChatNotificationSettingsModel(
      useDefaultMuteFor: json['use_default_mute_for'] as bool? ?? true,
      muteFor: tdIntOr(json['mute_for']),
      useDefaultShowPreview: json['use_default_show_preview'] as bool? ?? true,
      showPreview: json['show_preview'] as bool? ?? true,
      useDefaultSound: json['use_default_sound'] as bool? ?? true,
      soundId: tdIntOr(json['sound_id']),
    );
  }

  static int parseDefaultAutoDeleteSeconds(Map<String, dynamic> json) {
    if (json['@type'] == 'messageAutoDeleteTime') {
      return tdIntOr(json['time']);
    }
    final value = json['message_auto_delete_time'] as Map<String, dynamic>?;
    return tdIntOr(value?['time']);
  }

  static UnreadBadgeState parseUnreadBadge(Map<String, dynamic> update) {
    return UnreadBadgeState(
      unreadCount: tdIntOr(update['unread_count']),
      unreadUnmutedCount: tdIntOr(update['unread_unmuted_count']),
    );
  }
}
