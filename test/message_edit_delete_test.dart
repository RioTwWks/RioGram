import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/models/chat_models.dart';

void main() {
  group('ChatMessage edit/delete', () {
    test('canEditWithinWindow учитывает can_be_edited и 48 часов', () {
      final recent = ChatMessage.fromTdlib({
        '@type': 'message',
        'id': 1,
        'chat_id': 1,
        'date': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'is_outgoing': true,
        'can_be_edited': true,
        'content': {
          '@type': 'messageText',
          'text': {
            '@type': 'formattedText',
            'text': 'hello',
            'entities': [],
          },
        },
      });
      expect(recent.canEditWithinWindow, isTrue);
      expect(recent.canEditText, isTrue);

      final old = ChatMessage.fromTdlib({
        '@type': 'message',
        'id': 2,
        'chat_id': 1,
        'date': DateTime.now()
                .subtract(const Duration(hours: 49))
                .millisecondsSinceEpoch ~/
            1000,
        'is_outgoing': true,
        'can_be_edited': true,
        'content': {
          '@type': 'messageText',
          'text': {
            '@type': 'formattedText',
            'text': 'old',
            'entities': [],
          },
        },
      });
      expect(old.canEditWithinWindow, isFalse);
    });

    test('парсит edit_date и флаги удаления', () {
      final message = ChatMessage.fromTdlib({
        '@type': 'message',
        'id': 3,
        'chat_id': 1,
        'date': 1_700_000_000,
        'edit_date': 1_700_000_100,
        'is_outgoing': true,
        'can_be_edited': false,
        'can_be_deleted_only_for_self': true,
        'can_be_deleted_for_all_users': true,
        'content': {
          '@type': 'messageText',
          'text': {
            '@type': 'formattedText',
            'text': 'edited',
            'entities': [],
          },
        },
      });

      expect(message.isEdited, isTrue);
      expect(message.canBeDeletedForAllUsers, isTrue);
      expect(message.canBeEdited, isFalse);
    });

    test('editableComposerText возвращает текст и подпись', () {
      final textMessage = ChatMessage.fromTdlib({
        '@type': 'message',
        'id': 4,
        'chat_id': 1,
        'date': 1_700_000_000,
        'is_outgoing': true,
        'can_be_edited': true,
        'content': {
          '@type': 'messageText',
          'text': {
            '@type': 'formattedText',
            'text': 'body',
            'entities': [],
          },
        },
      });
      expect(textMessage.editableComposerText, 'body');

      final photo = ChatMessage.fromTdlib({
        '@type': 'message',
        'id': 5,
        'chat_id': 1,
        'date': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'is_outgoing': true,
        'can_be_edited': true,
        'content': {
          '@type': 'messagePhoto',
          'caption': {
            '@type': 'formattedText',
            'text': 'cap',
            'entities': [],
          },
          'photo': {'sizes': []},
        },
      });
      expect(photo.editableComposerText, 'cap');
      expect(photo.canEditCaption, isTrue);
    });
  });
}
