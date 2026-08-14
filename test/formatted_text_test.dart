import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/chat/formatted_text_builder.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:riogram/models/formatted_text.dart';

void main() {
  group('FormattedTextBuilder', () {
    test('парсит жирный и курсив', () {
      final formatted = FormattedTextBuilder.buildFromComposer('**bold** and *it*');
      expect(formatted.text, 'bold and it');
      expect(formatted.entities.length, 2);
      expect(formatted.entities[0].kind, TextEntityKind.bold);
      expect(formatted.entities[1].kind, TextEntityKind.italic);
    });

    test('парсит код и ссылку', () {
      final formatted = FormattedTextBuilder.buildFromComposer(
        'see `code` and [site](https://example.com)',
      );
      expect(formatted.text, 'see code and site');
      expect(
        formatted.entities.any((entity) => entity.kind == TextEntityKind.code),
        isTrue,
      );
      expect(
        formatted.entities.any(
          (entity) =>
              entity.kind == TextEntityKind.textUrl &&
              entity.url == 'https://example.com',
        ),
        isTrue,
      );
    });

    test('находит @mention и #hashtag', () {
      final formatted = FormattedTextBuilder.buildFromComposer('hi @user_name #tag');
      expect(
        formatted.entities.any((entity) => entity.kind == TextEntityKind.mention),
        isTrue,
      );
      expect(
        formatted.entities.any((entity) => entity.kind == TextEntityKind.hashtag),
        isTrue,
      );
    });
  });

  group('FormattedText.fromTdlib', () {
    test('читает entities из TDLib', () {
      final formatted = FormattedText.fromTdlib({
        '@type': 'formattedText',
        'text': 'Hello',
        'entities': [
          {
            '@type': 'textEntity',
            'offset': 0,
            'length': 5,
            'type': {'@type': 'textEntityTypeBold'},
          },
        ],
      });
      expect(formatted.text, 'Hello');
      expect(formatted.entities.single.kind, TextEntityKind.bold);
    });
  });

  group('ChatMessage.fromTdlib reply/forward', () {
    test('парсит reply_to и forward_info', () {
      final message = ChatMessage.fromTdlib({
        '@type': 'message',
        'id': 10,
        'chat_id': 1,
        'date': 1_700_000_000,
        'is_outgoing': true,
        'content': {
          '@type': 'messageText',
          'text': {
            '@type': 'formattedText',
            'text': 'answer',
            'entities': [],
          },
        },
        'reply_to': {
          '@type': 'messageReplyToMessage',
          'message_id': 5,
        },
        'forward_info': {
          '@type': 'messageForwardInfo',
          'origin': {'@type': 'messageOriginHiddenUser'},
        },
      });

      expect(message.replyTo?.messageId, 5);
      expect(message.forwardInfo?.isHiddenOrigin, isTrue);
    });
  });
}
