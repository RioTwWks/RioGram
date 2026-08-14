import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:riogram/models/message_enrichment.dart';

void main() {
  group('MessageEnrichmentParser delivery', () {
    test('pending / failed / sent / read для исходящих', () {
      final pending = MessageEnrichmentParser.parseDeliveryStatus(
        {
          'is_outgoing': true,
          'id': 10,
          'sending_state': {'@type': 'messageSendingStatePending'},
        },
        lastReadOutboxMessageId: 0,
      );
      expect(pending, MessageDeliveryStatus.sending);

      final failed = MessageEnrichmentParser.parseDeliveryStatus(
        {
          'is_outgoing': true,
          'id': 11,
          'sending_state': {'@type': 'messageSendingStateFailed'},
        },
        lastReadOutboxMessageId: 0,
      );
      expect(failed, MessageDeliveryStatus.failed);

      final sent = MessageEnrichmentParser.parseDeliveryStatus(
        {'is_outgoing': true, 'id': 12},
        lastReadOutboxMessageId: 11,
      );
      expect(sent, MessageDeliveryStatus.sent);

      final read = MessageEnrichmentParser.parseDeliveryStatus(
        {'is_outgoing': true, 'id': 12},
        lastReadOutboxMessageId: 12,
      );
      expect(read, MessageDeliveryStatus.read);
    });

    test('входящие сообщения без статуса доставки', () {
      expect(
        MessageEnrichmentParser.parseDeliveryStatus(
          {'is_outgoing': false, 'id': 1},
          lastReadOutboxMessageId: 99,
        ),
        isNull,
      );
    });
  });

  group('MessageEnrichmentParser reactions and keyboard', () {
    test('парсит реакции', () {
      final reactions = MessageEnrichmentParser.parseReactions({
        '@type': 'messageReactions',
        'reactions': [
          {
            'type': {'@type': 'reactionTypeEmoji', 'emoji': '🔥'},
            'total_count': 3,
            'is_chosen': true,
          },
        ],
      });
      expect(reactions, hasLength(1));
      expect(reactions.first.emoji, '🔥');
      expect(reactions.first.count, 3);
      expect(reactions.first.isChosen, isTrue);
    });

    test('парсит inline keyboard', () {
      final rows = MessageEnrichmentParser.parseInlineKeyboard({
        '@type': 'replyMarkupInlineKeyboard',
        'rows': [
          [
            {
              'text': 'Open',
              'type': {
                '@type': 'inlineKeyboardButtonTypeUrl',
                'url': 'https://example.com',
              },
            },
            {
              'text': 'Vote',
              'type': {
                '@type': 'inlineKeyboardButtonTypeCallback',
                'data': 'cb1',
              },
            },
          ],
        ],
      });
      expect(rows, hasLength(1));
      expect(rows.first, hasLength(2));
      expect(rows.first[0].url, 'https://example.com');
      expect(rows.first[1].callbackData, 'cb1');
    });
  });

  group('PollContent', () {
    test('парсит обычный опрос', () {
      final poll = PollContent.fromTdlib({
        'poll': {
          'question': {'text': 'Color?'},
          'options': [
            {
              'text': {'text': 'Red'},
              'voter_count': 2,
              'vote_percentage': 40,
              'is_chosen': false,
            },
            {
              'text': {'text': 'Blue'},
              'voter_count': 3,
              'vote_percentage': 60,
              'is_chosen': true,
            },
          ],
          'total_voter_count': 5,
          'is_closed': false,
          'is_anonymous': true,
          'type': {'@type': 'pollTypeRegular'},
        },
      });
      expect(poll.question, 'Color?');
      expect(poll.kind, PollKind.regular);
      expect(poll.options, hasLength(2));
      expect(poll.options[1].isChosen, isTrue);
    });

    test('парсит викторину', () {
      final poll = PollContent.fromTdlib({
        'poll': {
          'question': {'text': '2+2?'},
          'options': [
            {
              'text': {'text': '4'},
              'voter_count': 1,
              'vote_percentage': 100,
            },
          ],
          'total_voter_count': 1,
          'is_closed': false,
          'is_anonymous': false,
          'type': {
            '@type': 'pollTypeQuiz',
            'correct_option_id': 0,
          },
        },
      });
      expect(poll.kind, PollKind.quiz);
      expect(poll.correctOptionId, 0);
    });
  });

  group('ChatMessage enrichment', () {
    test('fromTdlib заполняет delivery, reactions, poll, keyboard', () {
      final message = ChatMessage.fromTdlib(
        {
          '@type': 'message',
          'id': 5,
          'chat_id': 1,
          'date': 1_700_000_000,
          'is_outgoing': true,
          'interaction_info': {
            '@type': 'messageInteractionInfo',
            'view_count': 42,
            'forward_count': 3,
          },
          'reactions': {
            '@type': 'messageReactions',
            'reactions': [
              {
                'type': {'@type': 'reactionTypeEmoji', 'emoji': '👍'},
                'total_count': 1,
                'is_chosen': false,
              },
            ],
          },
          'reply_markup': {
            '@type': 'replyMarkupInlineKeyboard',
            'rows': [
              [
                {
                  'text': 'Go',
                  'type': {
                    '@type': 'inlineKeyboardButtonTypeUrl',
                    'url': 'https://t.me',
                  },
                },
              ],
            ],
          },
          'content': {
            '@type': 'messagePoll',
            'poll': {
              'question': {'text': 'Q?'},
              'options': [
                {
                  'text': {'text': 'A'},
                  'voter_count': 0,
                  'vote_percentage': 0,
                },
              ],
              'total_voter_count': 0,
              'is_closed': false,
              'is_anonymous': true,
              'type': {'@type': 'pollTypeRegular'},
            },
          },
        },
        lastReadOutboxMessageId: 5,
      );

      expect(message.deliveryStatus, MessageDeliveryStatus.read);
      expect(message.interactionInfo?.viewCount, 42);
      expect(message.reactions, hasLength(1));
      expect(message.inlineKeyboard, hasLength(1));
      expect(message.content.kind, MessageKind.poll);
      expect(message.content.poll?.question, 'Q?');
    });
  });
}
