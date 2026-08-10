import 'package:flutter_test/flutter_test.dart';
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
}
