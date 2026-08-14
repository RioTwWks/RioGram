import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:riogram/models/media_models.dart';

void main() {
  group('MediaAlbumGrouper', () {
    ChatMessage msg(int id, {int? groupedId, MessageKind kind = MessageKind.photo}) {
      return ChatMessage.fromTdlib({
        '@type': 'message',
        'id': id,
        'chat_id': 1,
        'date': id,
        'grouped_id': groupedId,
        'content': {
          '@type': switch (kind) {
            MessageKind.video => 'messageVideo',
            MessageKind.videoNote => 'messageVideoNote',
            _ => 'messagePhoto',
          },
          if (kind == MessageKind.photo)
            'photo': {
              'sizes': [
                {'photo': {'id': id * 10}},
              ],
            },
          if (kind == MessageKind.video)
            'video': {
              'duration': 12,
              'width': 640,
              'height': 360,
              'video': {'id': id * 10},
            },
          if (kind == MessageKind.videoNote)
            'video_note': {
              'duration': 5,
              'length': 240,
              'video': {'id': id * 10},
            },
        },
      });
    }

    test('группирует сообщения с одинаковым grouped_id', () {
      final grouped = MediaAlbumGrouper.group([
        msg(1),
        msg(2, groupedId: 100),
        msg(3, groupedId: 100),
        msg(4, groupedId: 100),
        msg(5),
      ]);

      expect(grouped, hasLength(3));
      expect(grouped[0], isA<SingleChatMessageItem>());
      expect(grouped[1], isA<AlbumChatMessageItem>());
      expect((grouped[1] as AlbumChatMessageItem).albumMessages, hasLength(3));
    });
  });

  group('MessageContent video', () {
    test('парсит messageVideo с метаданными', () {
      final content = MessageContent.fromTdlib({
        '@type': 'messageVideo',
        'caption': {
          '@type': 'formattedText',
          'text': 'Клип',
        },
        'video': {
          'duration': 90,
          'width': 1280,
          'height': 720,
          'video': {'id': 77},
        },
      });

      expect(content.kind, MessageKind.video);
      expect(content.caption, 'Клип');
      expect(content.videoInfo?.durationSeconds, 90);
      expect(content.videoInfo?.durationLabel, '1:30');
    });

    test('парсит messageVideoNote', () {
      final content = MessageContent.fromTdlib({
        '@type': 'messageVideoNote',
        'video_note': {
          'duration': 8,
          'length': 240,
          'video': {'id': 88},
        },
      });

      expect(content.kind, MessageKind.videoNote);
      expect(content.videoInfo?.isVideoNote, isTrue);
      expect(content.videoInfo?.videoNoteLength, 240);
      expect(
        MessageContent.parseMediaFileId({
          '@type': 'messageVideoNote',
          'video_note': {'video': {'id': 88}},
        }),
        88,
      );
    });
  });

  group('ChatMessage grouped_id', () {
    test('fromTdlib сохраняет grouped_id', () {
      final message = ChatMessage.fromTdlib({
        '@type': 'message',
        'id': 9,
        'chat_id': 1,
        'date': 1,
        'grouped_id': 555,
        'content': {
          '@type': 'messagePhoto',
          'photo': {
            'sizes': [
              {'photo': {'id': 1}},
            ],
          },
        },
      });

      expect(message.groupedId, 555);
    });
  });

  group('MediaViewerItem', () {
    test('hasLocalFile false без пути', () {
      final message = ChatMessage.fromTdlib({
        '@type': 'message',
        'id': 1,
        'chat_id': 1,
        'date': 1,
        'content': {
          '@type': 'messagePhoto',
          'photo': {
            'sizes': [
              {'photo': {'id': 1}},
            ],
          },
        },
      });
      expect(MediaViewerItem.fromMessage(message).hasLocalFile, isFalse);
    });
  });
}
