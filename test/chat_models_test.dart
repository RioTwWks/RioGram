import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/chat/tdlib_chat_parser.dart';
import 'package:riogram/models/chat_models.dart';

void main() {
  test('MessageContent парсит текстовое сообщение', () {
    final content = MessageContent.fromTdlib({
      '@type': 'messageText',
      'text': {
        '@type': 'formattedText',
        'text': 'Привет, RioGram!',
      },
    });

    expect(content.kind, MessageKind.text);
    expect(content.preview, 'Привет, RioGram!');
  });

  test('MessageContent парсит фото с подписью', () {
    final content = MessageContent.fromTdlib({
      '@type': 'messagePhoto',
      'caption': {
        '@type': 'formattedText',
        'text': 'Закат',
      },
      'photo': {
        'sizes': [
          {
            'photo': {'id': 42},
          },
        ],
      },
    });

    expect(content.kind, MessageKind.photo);
    expect(content.caption, 'Закат');
    expect(MessageContent.parseMediaFileId({
      '@type': 'messagePhoto',
      'photo': {
        'sizes': [
          {'photo': {'id': 42}},
        ],
      },
    }), 42);
  });

  test('ChatMessage.fromTdlib сохраняет направление', () {
    final message = ChatMessage.fromTdlib({
      '@type': 'message',
      'id': 1,
      'chat_id': 10,
      'date': 1_700_000_000,
      'is_outgoing': true,
      'content': {
        '@type': 'messageText',
        'text': {'@type': 'formattedText', 'text': 'test'},
      },
    });

    expect(message.isOutgoing, isTrue);
    expect(message.content.preview, 'test');
  });

  test('ChatSummary.previewText показывает черновик', () {
    const chat = ChatSummary(
      id: 1,
      title: 'Test',
      lastMessage: 'Последнее',
      draftPreview: 'Не отправлено',
    );

    expect(chat.previewText, 'Черновик: Не отправлено');
  });

  test('ChatSummary.showsUnreadIndicator учитывает метку непрочитанного', () {
    const marked = ChatSummary(id: 1, title: 'A', isMarkedAsUnread: true);
    const withCount = ChatSummary(id: 2, title: 'B', unreadCount: 3);
    const read = ChatSummary(id: 3, title: 'C');

    expect(marked.showsUnreadIndicator, isTrue);
    expect(withCount.showsUnreadIndicator, isTrue);
    expect(read.showsUnreadIndicator, isFalse);
  });

  test('ChatSummary.canLeave только для групп и каналов', () {
    expect(const ChatSummary(id: 1, title: 'G', kind: ChatKind.group).canLeave, isTrue);
    expect(const ChatSummary(id: 2, title: 'C', kind: ChatKind.channel).canLeave, isTrue);
    expect(const ChatSummary(id: 3, title: 'P', kind: ChatKind.privateChat).canLeave, isFalse);
  });

  test('ChatSummary.compareInList сортирует закреплённые и по order', () {
    const pinned = ChatSummary(
      id: 1,
      title: 'Pinned',
      positions: [
        ChatPositionInfo(
          list: ChatListMain(),
          order: 100,
          isPinned: true,
        ),
      ],
    );
    const regular = ChatSummary(
      id: 2,
      title: 'Regular',
      positions: [
        ChatPositionInfo(
          list: ChatListMain(),
          order: 200,
          isPinned: false,
        ),
      ],
    );
    const older = ChatSummary(
      id: 3,
      title: 'Older',
      positions: [
        ChatPositionInfo(
          list: ChatListMain(),
          order: 50,
          isPinned: false,
        ),
      ],
    );

    const list = ChatListMain();
    final sorted = [older, regular, pinned]
      ..sort((a, b) => ChatSummary.compareInList(a, b, list));

    expect(sorted.map((chat) => chat.id).toList(), [1, 2, 3]);
  });

  test('ChatListKey.fromTdlib распознаёт архив и папку', () {
    expect(
      ChatListKey.fromTdlib({'@type': 'chatListArchive'}).storageId,
      'archive',
    );
    expect(
      ChatListKey.fromTdlib({
        '@type': 'chatListFolder',
        'chat_folder_id': 7,
      }).storageId,
      'folder_7',
    );
  });

  group('TdlibChatParser', () {
    test('parseChat извлекает mute, draft и тип канала', () {
      final chat = TdlibChatParser.parseChat({
        'id': 10,
        'title': 'News',
        'unread_count': 3,
        'type': {
          '@type': 'chatTypeSupergroup',
          'supergroup_id': 1,
          'is_channel': true,
        },
        'notification_settings': {
          'use_default_mute_for': false,
          'mute_for': 3600,
        },
        'draft_message': {
          'content': {
            '@type': 'draftMessageContentText',
            'text': {
              '@type': 'formattedText',
              'text': 'Черновик текста',
            },
          },
        },
        'positions': [
          {
            'list': {'@type': 'chatListMain'},
            'order': 123,
            'is_pinned': false,
          },
        ],
      });

      expect(chat, isNotNull);
      expect(chat!.kind, ChatKind.channel);
      expect(chat.isMuted, isTrue);
      expect(chat.draftPreview, 'Черновик текста');
      expect(chat.isInList(const ChatListMain()), isTrue);
    });

    test('parseChatType определяет бота и избранное', () {
      final saved = TdlibChatParser.parseChatType(
        {'@type': 'chatTypePrivate', 'user_id': 42},
        myUserId: 42,
      );
      expect(saved.kind, ChatKind.savedMessages);

      final bot = TdlibChatParser.parseChatType(
        {'@type': 'chatTypePrivate', 'user_id': 99},
        botUsers: {99: true},
      );
      expect(bot.kind, ChatKind.bot);
    });

    test('isChatMuted учитывает use_default_mute_for', () {
      expect(
        TdlibChatParser.isChatMuted({'use_default_mute_for': true, 'mute_for': 100}),
        isFalse,
      );
      expect(
        TdlibChatParser.isChatMuted({'use_default_mute_for': false, 'mute_for': 100}),
        isTrue,
      );
    });

    test('parseChatFolders возвращает вкладки папок', () {
      final folders = TdlibChatParser.parseChatFolders({
        'chat_folders': [
          {
            'id': 2,
            'name': {
              'text': {
                '@type': 'formattedText',
                'text': 'Работа',
              },
            },
            'icon': {'name': 'Briefcase'},
          },
        ],
      });

      expect(folders, hasLength(1));
      expect(folders.first.name, 'Работа');
      expect(folders.first.listKey.storageId, 'folder_2');
    });

    test('parseFoundMessages возвращает глобальные результаты', () {
      final hits = TdlibChatParser.parseFoundMessages({
        'messages': [
          {
            'id': 100,
            'chat_id': 42,
            'date': 1_700_000_000,
            'content': {
              '@type': 'messageText',
              'text': {'@type': 'formattedText', 'text': 'найдено'},
            },
          },
        ],
      });

      expect(hits, hasLength(1));
      expect(hits.first.chatId, 42);
      expect(hits.first.messageId, 100);
      expect(hits.first.preview, 'найдено');
    });
  });
}
