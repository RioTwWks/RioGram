import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/bot/tdlib_bot_parser.dart';
import 'package:riogram/models/bot_models.dart';
import 'package:riogram/models/message_enrichment.dart';

void main() {
  group('Inline keyboard parsing', () {
    test('parses callback and webApp buttons', () {
      final rows = MessageEnrichmentParser.parseInlineKeyboard({
        '@type': 'replyMarkupInlineKeyboard',
        'rows': [
          [
            {
              'text': 'Open',
              'type': {
                '@type': 'inlineKeyboardButtonTypeWebApp',
                'url': 'https://example.com/app',
              },
            },
            {
              'text': 'OK',
              'type': {
                '@type': 'inlineKeyboardButtonTypeCallback',
                'data': 'abc',
              },
            },
          ],
        ],
      });

      expect(rows, hasLength(1));
      expect(rows.first[0].kind, InlineKeyboardButtonKind.webApp);
      expect(rows.first[0].webAppUrl, 'https://example.com/app');
      expect(rows.first[1].kind, InlineKeyboardButtonKind.callback);
      expect(rows.first[1].callbackData, 'abc');
    });
  });

  group('BotSettingsJson', () {
    test('parseBotInfo reads commands', () {
      final info = BotSettingsJson.parseBotInfo({
        '@type': 'botInfo',
        'short_description': 'Test bot',
        'description': 'Long description',
        'commands': [
          {
            '@type': 'botCommand',
            'command': 'start',
            'description': 'Start bot',
            'is_ephemeral': false,
          },
        ],
        'menu_button': {'@type': 'botMenuButtonCommands'},
        'privacy_policy_url': '',
      });

      expect(info.commands, hasLength(1));
      expect(info.commands.first.slashCommand, '/start');
    });
  });

  group('TdlibBotParser', () {
    test('parseInlineComposerQuery extracts username and query', () {
      final parsed = TdlibBotParser.parseInlineComposerQuery('@gif cats');
      expect(parsed?.username, 'gif');
      expect(parsed?.query, 'cats');
    });
  });
}
