import 'chat_models.dart';

/// Фильтр глобального / локального поиска сообщений.
enum SearchMessageFilterKind {
  all,
  media,
  links,
  files,
  audio,
  voice;

  String get label => switch (this) {
        SearchMessageFilterKind.all => 'Все',
        SearchMessageFilterKind.media => 'Медиа',
        SearchMessageFilterKind.links => 'Ссылки',
        SearchMessageFilterKind.files => 'Файлы',
        SearchMessageFilterKind.audio => 'Аудио',
        SearchMessageFilterKind.voice => 'Голос',
      };

  Map<String, dynamic> toTdlib() => switch (this) {
        SearchMessageFilterKind.all => {'@type': 'searchMessagesFilterEmpty'},
        SearchMessageFilterKind.media => {
            '@type': 'searchMessagesFilterPhotoAndVideo',
          },
        SearchMessageFilterKind.links => {'@type': 'searchMessagesFilterUrl'},
        SearchMessageFilterKind.files => {'@type': 'searchMessagesFilterDocument'},
        SearchMessageFilterKind.audio => {'@type': 'searchMessagesFilterAudio'},
        SearchMessageFilterKind.voice => {
            '@type': 'searchMessagesFilterVoiceNote',
          },
      };
}

/// Найденный пользователь (по телефону / токену / username).
class SearchUserHit {
  const SearchUserHit({
    required this.userId,
    required this.displayName,
    this.username,
    this.isBot = false,
  });

  final int userId;
  final String displayName;
  final String? username;
  final bool isBot;
}

/// Публичный чат / канал / бот из discovery-поиска.
class PublicChatHit {
  const PublicChatHit({
    required this.chatId,
    required this.title,
    this.username,
    this.isBot = false,
    this.needsJoin = false,
  });

  final int chatId;
  final String title;
  final String? username;
  final bool isBot;
  final bool needsJoin;
}

/// Состояние поиска сообщений внутри чата.
class ChatMessageSearchState {
  const ChatMessageSearchState({
    this.query = '',
    this.filter = SearchMessageFilterKind.all,
    this.results = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
    this.totalCount = 0,
  });

  final String query;
  final SearchMessageFilterKind filter;
  final List<SearchMessageHit> results;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int totalCount;

  bool get isActive => query.isNotEmpty;

  ChatMessageSearchState copyWith({
    String? query,
    SearchMessageFilterKind? filter,
    List<SearchMessageHit>? results,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    int? totalCount,
  }) {
    return ChatMessageSearchState(
      query: query ?? this.query,
      filter: filter ?? this.filter,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}
