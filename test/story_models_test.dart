import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/stories/tdlib_story_parser.dart';
import 'package:riogram/models/story_models.dart';

void main() {
  group('TdlibStoryParser', () {
    test('parseChatActiveStories maps unread state', () {
      final poster = TdlibStoryParser.parseChatActiveStories({
        '@type': 'chatActiveStories',
        'chat_id': 100,
        'order': 5,
        'can_be_archived': true,
        'max_read_story_id': 2,
        'stories': [
          {
            '@type': 'storyInfo',
            'story_id': 2,
            'date': 1_700_000_000,
            'is_for_close_friends': false,
            'is_live': false,
          },
          {
            '@type': 'storyInfo',
            'story_id': 3,
            'date': 1_700_000_100,
            'is_for_close_friends': false,
            'is_live': false,
          },
        ],
      });

      expect(poster, isNotNull);
      expect(poster!.chatId, 100);
      expect(poster.hasUnread, isTrue);
      expect(poster.readState, StoryReadState.unread);
    });

    test('parseStory extracts photo file and caption', () {
      final story = TdlibStoryParser.parseStory({
        '@type': 'story',
        'id': 7,
        'poster_chat_id': 42,
        'date': 1_700_000_000,
        'can_be_replied': true,
        'can_be_forwarded': false,
        'caption': {
          '@type': 'formattedText',
          'text': 'Привет',
        },
        'content': {
          '@type': 'storyContentPhoto',
          'photo': {
            '@type': 'photo',
            'sizes': [
              {
                '@type': 'photoSize',
                'width': 720,
                'height': 1280,
                'photo': {
                  '@type': 'file',
                  'id': 99,
                  'local': {
                    '@type': 'localFile',
                    'path': '/tmp/story.jpg',
                    'is_downloading_completed': true,
                  },
                },
              },
            ],
          },
        },
      });

      expect(story, isNotNull);
      expect(story!.mediaKind, StoryMediaKind.photo);
      expect(story.mediaFileId, 99);
      expect(story.mediaLocalPath, '/tmp/story.jpg');
      expect(story.caption, 'Привет');
      expect(story.canBeReplied, isTrue);
    });

    test('parseAvailableReactions falls back to defaults', () {
      final reactions = TdlibStoryParser.parseAvailableReactions(null);
      expect(reactions, isNotEmpty);
      expect(reactions.first.emoji, '❤️');
    });
  });
}
