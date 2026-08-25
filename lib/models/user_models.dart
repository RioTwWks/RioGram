import 'bot_models.dart';

/// Тип статуса пользователя TDLib.
enum UserStatusKind {
  empty,
  online,
  offline,
  recently,
  lastWeek,
  lastMonth,
  unknown,
}

/// Статус онлайн / last seen.
class UserStatusInfo {
  const UserStatusInfo({
    required this.kind,
    this.expiresAt,
    this.wasOnlineAt,
    this.byMyPrivacySettings = false,
  });

  final UserStatusKind kind;
  final DateTime? expiresAt;
  final DateTime? wasOnlineAt;
  final bool byMyPrivacySettings;

  bool get isOnline => kind == UserStatusKind.online;
}

/// Краткая карточка пользователя (`user`).
class UserSummary {
  const UserSummary({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.username,
    this.phoneNumber = '',
    this.isContact = false,
    this.isMutualContact = false,
    this.isPremium = false,
    this.isBot = false,
    this.status = const UserStatusInfo(kind: UserStatusKind.empty),
    this.avatarFileId,
    this.avatarLocalPath,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String? username;
  final String phoneNumber;
  final bool isContact;
  final bool isMutualContact;
  final bool isPremium;
  final bool isBot;
  final UserStatusInfo status;
  final int? avatarFileId;
  final String? avatarLocalPath;

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isNotEmpty ? full : (username ?? 'Пользователь');
  }

  UserSummary copyWith({
    String? firstName,
    String? lastName,
    String? username,
    String? phoneNumber,
    bool? isContact,
    bool? isMutualContact,
    bool? isPremium,
    bool? isBot,
    UserStatusInfo? status,
    int? avatarFileId,
    String? avatarLocalPath,
  }) {
    return UserSummary(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isContact: isContact ?? this.isContact,
      isMutualContact: isMutualContact ?? this.isMutualContact,
      isPremium: isPremium ?? this.isPremium,
      isBot: isBot ?? this.isBot,
      status: status ?? this.status,
      avatarFileId: avatarFileId ?? this.avatarFileId,
      avatarLocalPath: avatarLocalPath ?? this.avatarLocalPath,
    );
  }
}

/// Расширенный профиль (`userFullInfo`).
class UserProfileFullInfo {
  const UserProfileFullInfo({
    required this.userId,
    this.bio = '',
    this.isBlocked = false,
    this.canBeCalled = false,
    this.supportsVideoCalls = false,
    this.groupInCommonCount = 0,
    this.personalChatId,
    this.botInfo = const BotInfoModel(),
  });

  final int userId;
  final String bio;
  final bool isBlocked;
  final bool canBeCalled;
  final bool supportsVideoCalls;
  final int groupInCommonCount;
  final int? personalChatId;
  final BotInfoModel botInfo;
}

/// Заблокированный пользователь.
class BlockedUserSummary {
  const BlockedUserSummary({
    required this.userId,
    this.displayName,
  });

  final int userId;
  final String? displayName;
}

/// Общий чат с пользователем (кратко).
class CommonChatSummary {
  const CommonChatSummary({
    required this.id,
    required this.title,
  });

  final int id;
  final String title;
}

/// Контакт для импорта из адресной книги.
class PhoneBookContactDraft {
  const PhoneBookContactDraft({
    required this.phoneNumber,
    required this.firstName,
    this.lastName = '',
  });

  final String phoneNumber;
  final String firstName;
  final String lastName;
}

/// Результат импорта контактов.
class ImportedContactsResult {
  const ImportedContactsResult({
    this.importedCount = 0,
    this.userIds = const [],
  });

  final int importedCount;
  final List<int> userIds;
}

/// Собственный профиль для редактирования.
class OwnProfileDraft {
  const OwnProfileDraft({
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.username = '',
    this.bio = '',
    this.avatarLocalPath,
  });

  final int userId;
  final String firstName;
  final String lastName;
  final String username;
  final String bio;
  final String? avatarLocalPath;

  String get displayName => '$firstName $lastName'.trim();
}
