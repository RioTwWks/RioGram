import '../../models/bot_models.dart';

/// Парсинг bot- и inline-ответов TDLib.
class TdlibBotParser {
  static BotInfoModel parseBotInfo(Map<String, dynamic>? json) {
    return BotSettingsJson.parseBotInfo(json);
  }

  static CallbackQueryAnswerModel parseCallbackAnswer(
    Map<String, dynamic> json,
  ) {
    return BotSettingsJson.parseCallbackAnswer(json);
  }

  static List<InlineQueryResultModel> parseInlineQueryResults(
    Map<String, dynamic> json,
  ) {
    return BotSettingsJson.parseInlineQueryResults(json);
  }

  static Map<String, dynamic> callbackPayload(String data) {
    return {
      '@type': 'callbackQueryPayloadData',
      'data': data,
    };
  }

  static Map<String, dynamic> callbackGamePayload() {
    return {
      '@type': 'callbackQueryPayloadGame',
      'game_short_name': '',
    };
  }

  static int? parseBotUserIdFromInlineQuery(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('@')) {
      return null;
    }
    final space = trimmed.indexOf(' ');
    final username = space == -1
        ? trimmed.substring(1)
        : trimmed.substring(1, space);
    if (username.isEmpty) {
      return null;
    }
    return null;
  }

  static ({String username, String query})? parseInlineComposerQuery(
    String text,
  ) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('@')) {
      return null;
    }
    final space = trimmed.indexOf(' ');
    if (space <= 1) {
      return null;
    }
    final username = trimmed.substring(1, space);
    final query = trimmed.substring(space + 1).trim();
    if (username.isEmpty) {
      return null;
    }
    return (username: username, query: query);
  }

  static int? resolveBotUserId({
    required String username,
    required Map<String, int> usernameToUserId,
  }) {
    return usernameToUserId[username.toLowerCase()];
  }
}
