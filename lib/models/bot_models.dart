import '../core/tdlib/tdlib_json.dart';

/// Команда бота из userFullInfo.bot_info.
class BotCommandModel {
  const BotCommandModel({
    required this.command,
    required this.description,
    this.isEphemeral = false,
  });

  final String command;
  final String description;
  final bool isEphemeral;

  String get slashCommand =>
      command.startsWith('/') ? command : '/$command';
}

/// Кнопка меню бота (Web App / commands / default).
class BotMenuButtonModel {
  const BotMenuButtonModel({
    this.kind = BotMenuButtonKind.defaultButton,
    this.text = '',
    this.webAppUrl = '',
  });

  final BotMenuButtonKind kind;
  final String text;
  final String webAppUrl;
}

enum BotMenuButtonKind {
  defaultButton,
  commands,
  webApp,
}

/// Информация о боте из userFullInfo.bot_info.
class BotInfoModel {
  const BotInfoModel({
    this.shortDescription = '',
    this.description = '',
    this.commands = const [],
    this.menuButton = const BotMenuButtonModel(),
    this.privacyPolicyUrl = '',
  });

  final String shortDescription;
  final String description;
  final List<BotCommandModel> commands;
  final BotMenuButtonModel menuButton;
  final String privacyPolicyUrl;
}

/// Ответ на нажатие inline-кнопки.
class CallbackQueryAnswerModel {
  const CallbackQueryAnswerModel({
    this.text = '',
    this.showAlert = false,
    this.url = '',
  });

  final String text;
  final bool showAlert;
  final String url;
}

/// Результат inline-запроса для отправки в чат.
class InlineQueryResultModel {
  const InlineQueryResultModel({
    required this.id,
    required this.title,
    this.description = '',
    this.preview = '',
  });

  final String id;
  final String title;
  final String description;
  final String preview;
}

/// Состояние inline-режима в композере.
class InlineQueryState {
  const InlineQueryState({
    this.botUserId,
    this.botUsername = '',
    this.query = '',
    this.results = const [],
    this.queryId = 0,
    this.isLoading = false,
    this.error,
  });

  final int? botUserId;
  final String botUsername;
  final String query;
  final List<InlineQueryResultModel> results;
  final int queryId;
  final bool isLoading;
  final String? error;

  bool get isActive => botUserId != null && query.isNotEmpty;
}

/// Парсинг botInfo и inline-результатов TDLib.
class BotSettingsJson {
  static BotInfoModel parseBotInfo(Map<String, dynamic>? json) {
    if (json == null || json['@type'] != 'botInfo') {
      return const BotInfoModel();
    }

    final commandsRaw = json['commands'] as List<dynamic>? ?? const [];
    final menu = json['menu_button'] as Map<String, dynamic>? ?? const {};
    final menuType = menu['@type'] as String? ?? '';

    return BotInfoModel(
      shortDescription: json['short_description'] as String? ?? '',
      description: json['description'] as String? ?? '',
      commands: commandsRaw
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => BotCommandModel(
              command: item['command'] as String? ?? '',
              description: item['description'] as String? ?? '',
              isEphemeral: item['is_ephemeral'] as bool? ?? false,
            ),
          )
          .where((item) => item.command.isNotEmpty)
          .toList(growable: false),
      menuButton: BotMenuButtonModel(
        kind: switch (menuType) {
          'botMenuButtonCommands' => BotMenuButtonKind.commands,
          'botMenuButtonWebApp' => BotMenuButtonKind.webApp,
          _ => BotMenuButtonKind.defaultButton,
        },
        text: menu['text'] as String? ?? '',
        webAppUrl: menu['url'] as String? ?? '',
      ),
      privacyPolicyUrl: json['privacy_policy_url'] as String? ?? '',
    );
  }

  static CallbackQueryAnswerModel parseCallbackAnswer(
    Map<String, dynamic> json,
  ) {
    return CallbackQueryAnswerModel(
      text: json['text'] as String? ?? '',
      showAlert: json['show_alert'] as bool? ?? false,
      url: json['url'] as String? ?? '',
    );
  }

  static List<InlineQueryResultModel> parseInlineQueryResults(
    Map<String, dynamic> json,
  ) {
    final results = json['results'] as List<dynamic>? ?? const [];
    return results.whereType<Map<String, dynamic>>().map((item) {
      final content = item['content'] as Map<String, dynamic>? ?? const {};
      final title = item['title'] as String? ?? '';
      final description = item['description'] as String? ?? '';
      final preview = switch (content['@type']) {
        'inlineQueryResultArticle' =>
          (content['title'] as String?) ?? title,
        'inlineQueryResultAnimation' => '🎞 GIF',
        'inlineQueryResultPhoto' => '📷 Фото',
        'inlineQueryResultVideo' => '🎬 Видео',
        _ => title,
      };
      return InlineQueryResultModel(
        id: item['id'] as String? ?? '',
        title: title,
        description: description,
        preview: preview,
      );
    }).where((item) => item.id.isNotEmpty).toList(growable: false);
  }

  static int parseInlineQueryId(Map<String, dynamic> json) {
    return tdIntOr(json['inline_query_id']);
  }
}
