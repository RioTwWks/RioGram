import 'chat_models.dart';

/// Расширенная информация о типе чата из TDLib `ChatType`.
class ChatTypeInfo {
  const ChatTypeInfo({
    required this.kind,
    this.privateUserId,
    this.basicGroupId,
    this.supergroupId,
    this.secretChatId,
    this.isForum = false,
  });

  final ChatKind kind;
  final int? privateUserId;
  final int? basicGroupId;
  final int? supergroupId;
  final int? secretChatId;
  final bool isForum;

  bool get isBasicGroup => basicGroupId != null;
  bool get isSupergroup => supergroupId != null;
  bool get isChannel => kind == ChatKind.channel;
}

/// Результат создания базовой группы.
class CreatedBasicGroupResult {
  const CreatedBasicGroupResult({
    required this.chatId,
    this.failedUserIds = const [],
  });

  final int chatId;
  final List<int> failedUserIds;
}

/// Парсинг @username и invite-ссылок для публичных чатов.
class PublicChatLinkParser {
  const PublicChatLinkParser._();

  static String? parseUsername(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed.startsWith('http') ? trimmed : 'https://$trimmed');
    if (uri != null &&
        (uri.host.contains('t.me') || uri.host.contains('telegram.me'))) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) {
        return null;
      }
      if (segments.first == 'joinchat' || segments.first.startsWith('+')) {
        return null;
      }
      final username = segments.last;
      return _isValidUsername(username) ? username : null;
    }

    var value = trimmed;
    if (value.startsWith('@')) {
      value = value.substring(1);
    }
    return _isValidUsername(value) ? value : null;
  }

  static String? parseInviteLink(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed.contains('joinchat/')) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed.startsWith('http') ? trimmed : 'https://$trimmed');
    if (uri != null &&
        (uri.host.contains('t.me') || uri.host.contains('telegram.me'))) {
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'joinchat') {
        return trimmed.startsWith('http') ? trimmed : 'https://$trimmed';
      }
      if (uri.path.startsWith('/+')) {
        return trimmed.startsWith('http') ? trimmed : 'https://$trimmed';
      }
    }

    if (trimmed.startsWith('+') && trimmed.length > 8) {
      return 'https://t.me/$trimmed';
    }

    return null;
  }

  static bool _isValidUsername(String value) {
    return RegExp(r'^[A-Za-z0-9_]{4,32}$').hasMatch(value);
  }
}
