import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/chat/tdlib_forum_parser.dart';
import 'package:riogram/models/forum_models.dart';

void main() {
  group('TdlibForumParser', () {
    test('parseForumTopic различает General и именованные темы', () {
      final general = TdlibForumParser.parseForumTopic({
        '@type': 'forumTopic',
        'info': {
          '@type': 'forumTopicInfo',
          'forum_topic_id': 1,
          'name': 'General',
          'is_general': true,
          'is_closed': false,
        },
        'order': 100,
        'is_pinned': true,
        'unread_count': 3,
        'last_message': {
          '@type': 'message',
          'date': 1_700_000_000,
          'content': {
            '@type': 'messageText',
            'text': {'@type': 'formattedText', 'text': 'Hello'},
          },
        },
      });

      final named = TdlibForumParser.parseForumTopic({
        '@type': 'forumTopic',
        'info': {
          '@type': 'forumTopicInfo',
          'forum_topic_id': 42,
          'name': 'Dev chat',
          'is_general': false,
          'is_closed': true,
        },
        'order': 50,
        'is_pinned': false,
        'unread_count': 0,
      });

      expect(general?.displayName, 'General');
      expect(general?.isGeneral, isTrue);
      expect(general?.isPinned, isTrue);
      expect(general?.unreadCount, 3);
      expect(general?.lastMessagePreview, 'Hello');

      expect(named?.displayName, 'Dev chat');
      expect(named?.isGeneral, isFalse);
      expect(named?.isClosed, isTrue);
    });

    test('parseForumTopics сортирует по order', () {
      final topics = TdlibForumParser.parseForumTopics({
        '@type': 'forumTopics',
        'total_count': 2,
        'topics': [
          {
            '@type': 'forumTopic',
            'info': {
              '@type': 'forumTopicInfo',
              'forum_topic_id': 2,
              'name': 'B',
              'is_general': false,
            },
            'order': 10,
          },
          {
            '@type': 'forumTopic',
            'info': {
              '@type': 'forumTopicInfo',
              'forum_topic_id': 1,
              'name': 'General',
              'is_general': true,
            },
            'order': 100,
          },
        ],
      });

      expect(topics.length, 2);
      expect(topics.first.forumTopicId, 1);
      expect(topics.first.isGeneral, isTrue);
    });

    test('parseForumTopicInfo для createForumTopic', () {
      final topic = TdlibForumParser.parseForumTopicInfo({
        '@type': 'forumTopicInfo',
        'forum_topic_id': 99,
        'name': 'New topic',
        'is_general': false,
        'is_closed': false,
      });

      expect(topic?.forumTopicId, 99);
      expect(topic?.name, 'New topic');
    });
  });

  group('ForumTopicSummary', () {
    test('displayName для General всегда General', () {
      const topic = ForumTopicSummary(
        forumTopicId: 1,
        name: 'Общая',
        isGeneral: true,
      );
      expect(topic.displayName, 'General');
    });
  });
}
