import '../../models/chat_models.dart';

/// Резолвер имён пользователей и чатов для групповых сообщений.
class GroupMessageNameResolver {
  const GroupMessageNameResolver({
    required this.userName,
    this.chatTitle,
  });

  final String Function(int userId) userName;
  final String Function(int chatId)? chatTitle;

  String resolveUser(int userId) {
    if (userId == 0) {
      return 'участник';
    }
    final name = userName(userId).trim();
    return name.isEmpty ? 'участник' : name;
  }

  String resolveChat(int chatId) {
    if (chatId == 0) {
      return 'чат';
    }
    final title = chatTitle?.call(chatId).trim() ?? '';
    return title.isEmpty ? 'чат' : title;
  }
}

/// Парсинг отправителя и служебных сообщений групповых чатов.
class TdlibGroupMessageParser {
  const TdlibGroupMessageParser._();

  static const serviceContentTypes = {
    'messageBasicGroupChatCreate',
    'messageSupergroupChatCreate',
    'messageChatChangeTitle',
    'messageChatChangePhoto',
    'messageChatDeletePhoto',
    'messageChatAddMembers',
    'messageChatJoinByLink',
    'messageChatJoinByRequest',
    'messageChatDeleteMember',
    'messageChatUpgradeTo',
    'messageChatUpgradeFrom',
    'messageChatOwnerChanged',
    'messageChatOwnerLeft',
    'messagePinMessage',
  };

  static bool isServiceContentType(String type) =>
      serviceContentTypes.contains(type);

  static ({int? userId, int? chatId}) parseSenderIds(
    Map<String, dynamic>? senderId,
  ) {
    if (senderId == null) {
      return (userId: null, chatId: null);
    }
    return switch (senderId['@type']) {
      'messageSenderUser' => (userId: senderId['user_id'] as int?, chatId: null),
      'messageSenderChat' => (userId: null, chatId: senderId['chat_id'] as int?),
      _ => (userId: null, chatId: null),
    };
  }

  static String? parseSenderDisplayName(
    Map<String, dynamic>? senderId,
    GroupMessageNameResolver resolver,
  ) {
    if (senderId == null) {
      return null;
    }
    return switch (senderId['@type']) {
      'messageSenderUser' =>
        resolver.resolveUser(senderId['user_id'] as int? ?? 0),
      'messageSenderChat' =>
        resolver.resolveChat(senderId['chat_id'] as int? ?? 0),
      _ => null,
    };
  }

  static MessageContent? parseServiceContent(
    Map<String, dynamic> content,
    GroupMessageNameResolver resolver, {
    Map<String, dynamic>? senderId,
  }) {
    final type = content['@type'] as String? ?? '';
    if (!isServiceContentType(type)) {
      return null;
    }

    final senderName = parseSenderDisplayName(senderId, resolver);
    final preview = _formatServicePreview(
      type,
      content,
      resolver,
      senderName: senderName,
    );
    final userIds = _collectServiceUserIds(type, content);

    return MessageContent(
      kind: MessageKind.service,
      preview: preview,
      serviceContentRaw: Map<String, dynamic>.from(content),
      serviceUserIds: userIds,
    );
  }

  static List<int> _collectServiceUserIds(
    String type,
    Map<String, dynamic> content,
  ) {
    return switch (type) {
      'messageChatAddMembers' => _intList(content['member_user_ids']),
      'messageBasicGroupChatCreate' => _intList(content['member_user_ids']),
      'messageChatDeleteMember' => [content['user_id'] as int? ?? 0],
      'messageChatOwnerChanged' ||
      'messageChatOwnerLeft' =>
        [content['new_owner_user_id'] as int? ?? 0],
      _ => const [],
    };
  }

  static List<int> _intList(dynamic raw) {
    if (raw is! List) {
      return const [];
    }
    return raw.whereType<int>().where((id) => id != 0).toList();
  }

  static String _formatServicePreview(
    String type,
    Map<String, dynamic> content,
    GroupMessageNameResolver resolver, {
    String? senderName,
  }) {
    return switch (type) {
      'messageBasicGroupChatCreate' => () {
          final title = content['title'] as String? ?? '';
          if (title.isEmpty) {
            return 'Группа создана';
          }
          return 'Создана группа «$title»';
        }(),
      'messageSupergroupChatCreate' => () {
          final title = content['title'] as String? ?? '';
          if (title.isEmpty) {
            return 'Супергруппа создана';
          }
          return 'Создана супергруппа «$title»';
        }(),
      'messageChatChangeTitle' => () {
          final title = content['title'] as String? ?? '';
          return title.isEmpty
              ? 'Название группы изменено'
              : 'Название изменено на «$title»';
        }(),
      'messageChatChangePhoto' => 'Фото группы обновлено',
      'messageChatDeletePhoto' => 'Фото группы удалено',
      'messageChatAddMembers' => _formatAddMembers(
          content,
          resolver,
          senderName: senderName,
        ),
      'messageChatJoinByLink' => senderName == null
          ? 'Участник вступил по ссылке-приглашению'
          : '$senderName вступил(а) по ссылке-приглашению',
      'messageChatJoinByRequest' => senderName == null
          ? 'Отправлен запрос на вступление'
          : '$senderName отправил(а) запрос на вступление',
      'messageChatDeleteMember' => _formatDeleteMember(
          content,
          resolver,
          senderName: senderName,
        ),
      'messageChatUpgradeTo' => 'Группа преобразована в супергруппу',
      'messageChatUpgradeFrom' => () {
          final title = content['title'] as String? ?? '';
          return title.isEmpty
              ? 'Супергруппа создана из группы'
              : 'Супергруппа «$title» создана из группы';
        }(),
      'messageChatOwnerChanged' => () {
          final ownerId = content['new_owner_user_id'] as int? ?? 0;
          final ownerName = resolver.resolveUser(ownerId);
          return 'Новый владелец — $ownerName';
        }(),
      'messageChatOwnerLeft' => () {
          final ownerId = content['new_owner_user_id'] as int? ?? 0;
          final ownerName = resolver.resolveUser(ownerId);
          return '$ownerName назначен(а) владельцем';
        }(),
      'messagePinMessage' => senderName == null
          ? 'Сообщение закреплено'
          : '$senderName закрепил(а) сообщение',
      _ => 'Служебное сообщение',
    };
  }

  static String _formatAddMembers(
    Map<String, dynamic> content,
    GroupMessageNameResolver resolver, {
    String? senderName,
  }) {
    final memberIds = _intList(content['member_user_ids']);
    if (memberIds.isEmpty) {
      return 'Участники добавлены';
    }

    final membersLabel = _joinNames(
      memberIds.map(resolver.resolveUser).toList(),
    );

    if (memberIds.length == 1 && senderName != null) {
      final memberName = resolver.resolveUser(memberIds.first);
      if (memberName != senderName) {
        return '$senderName добавил(а) $memberName';
      }
      return '$memberName вступил(а) в группу';
    }

    if (senderName != null && memberIds.length > 1) {
      return '$senderName добавил(а) $membersLabel';
    }

    return '$membersLabel вступил(и) в группу';
  }

  static String _formatDeleteMember(
    Map<String, dynamic> content,
    GroupMessageNameResolver resolver, {
    String? senderName,
  }) {
    final userId = content['user_id'] as int? ?? 0;
    final memberName = resolver.resolveUser(userId);
    if (senderName != null && memberName != senderName) {
      return '$senderName удалил(а) $memberName';
    }
    return '$memberName покинул(а) группу';
  }

  static String _joinNames(List<String> names) {
    final filtered = names.where((name) => name.isNotEmpty).toList();
    if (filtered.isEmpty) {
      return 'участник';
    }
    if (filtered.length == 1) {
      return filtered.first;
    }
    if (filtered.length == 2) {
      return '${filtered[0]} и ${filtered[1]}';
    }
    final head = filtered.sublist(0, filtered.length - 1).join(', ');
    return '$head и ${filtered.last}';
  }
}
