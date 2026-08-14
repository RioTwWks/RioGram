import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:riogram/models/sticker_models.dart';

void main() {
  group('StickerLinkParser', () {
    test('распознаёт t.me/addstickers/Name', () {
      expect(
        StickerLinkParser.parseSetName('https://t.me/addstickers/MyPack'),
        'MyPack',
      );
    });

    test('распознаёт короткую ссылку addstickers', () {
      expect(
        StickerLinkParser.parseSetName('addstickers/Test_123'),
        'Test_123',
      );
    });
  });

  group('StickerModel', () {
    test('парсит стикер из TDLib', () {
      final sticker = StickerModel.fromTdlib({
        'sticker': {'id': 100},
        'set_id': 5,
        'width': 512,
        'height': 512,
        'emoji': '😀',
        'format': {'@type': 'stickerFormatWebp'},
      });

      expect(sticker.fileId, 100);
      expect(sticker.emoji, '😀');
      expect(sticker.isAnimated, isFalse);
      expect(sticker.isVideo, isFalse);
    });

    test('формирует inputMessageSticker', () {
      const sticker = StickerModel(
        fileId: 42,
        setId: 1,
        width: 512,
        height: 512,
        emoji: '🎉',
      );

      final payload = sticker.toInputMessageSticker();
      expect(payload['@type'], 'inputMessageSticker');
      expect(payload['emoji'], '🎉');
      expect(payload['sticker']['@type'], 'inputSticker');
      expect(payload['sticker']['sticker']['id'], 42);
    });
  });

  group('MessageContent sticker/animation', () {
    test('парсит messageSticker', () {
      final content = MessageContent.fromTdlib({
        '@type': 'messageSticker',
        'sticker': {
          'sticker': {'id': 77},
          'emoji': '🔥',
          'width': 512,
          'height': 512,
        },
      });

      expect(content.kind, MessageKind.sticker);
      expect(content.preview, '🔥');
      expect(content.stickerInfo?.sticker.fileId, 77);
      expect(
        MessageContent.parseMediaFileId({
          '@type': 'messageSticker',
          'sticker': {
            'sticker': {'id': 77},
          },
        }),
        77,
      );
    });

    test('парсит messageAnimation', () {
      final content = MessageContent.fromTdlib({
        '@type': 'messageAnimation',
        'animation': {
          'animation': {'id': 88},
          'width': 320,
          'height': 240,
          'duration': 5,
        },
        'caption': {
          '@type': 'formattedText',
          'text': 'GIF caption',
        },
      });

      expect(content.kind, MessageKind.animation);
      expect(content.animationInfo?.animation.fileId, 88);
      expect(content.caption, 'GIF caption');
    });
  });
}
