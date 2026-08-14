import '../../models/formatted_text.dart';

/// Сборка formattedText из composer: markdown + @mention + #hashtag.
class FormattedTextBuilder {
  const FormattedTextBuilder._();

  /// Разметка composer:
  /// - `**жирный**`, `*курсив*`, `_курсив_`
  /// - `` `код` ``
  /// - `[текст](https://url)`
  /// - `@username`, `#hashtag` — авто при отправке
  static FormattedText buildFromComposer(String raw) {
    final text = raw.replaceAll('\r\n', '\n');
    if (text.isEmpty) {
      return const FormattedText(text: '');
    }

    final segments = <_Segment>[];
    _parseInlineMarkdown(text, segments);
    final plain = segments.map((segment) => segment.plain).join();

    final entities = <TextEntity>[];
    var offset = 0;
    for (final segment in segments) {
      entities.addAll(
        segment.entities.map(
          (entity) => TextEntity(
            offset: entity.offset + offset,
            length: entity.length,
            kind: entity.kind,
            url: entity.url,
          ),
        ),
      );
      offset += segment.plain.length;
    }

    entities.addAll(_detectMentionsAndHashtags(plain, entities));

    final merged = _mergeEntities(entities);
    return FormattedText(text: plain, entities: merged);
  }

  static void _parseInlineMarkdown(String input, List<_Segment> output) {
    var index = 0;
    while (index < input.length) {
      final rest = input.substring(index);

      final patterns = [
        _tryMatch(rest, RegExp(r'^\*\*(.+?)\*\*'), TextEntityKind.bold, 2, 2),
        _tryMatch(rest, RegExp(r'^\*(.+?)\*'), TextEntityKind.italic, 1, 1),
        _tryMatch(rest, RegExp(r'^_(.+?)_'), TextEntityKind.italic, 1, 1),
        _tryMatch(rest, RegExp(r'^`([^`]+)`'), TextEntityKind.code, 1, 1),
        _tryMatchLink(rest),
      ].whereType<_MarkdownMatch>();

      final match = patterns.isEmpty ? null : patterns.first;
      if (match != null) {
        output.add(
          _Segment(
            plain: match.inner,
            entities: [
              TextEntity(
                offset: 0,
                length: match.inner.length,
                kind: match.kind,
                url: match.url,
              ),
            ],
          ),
        );
        index += match.fullLength;
        continue;
      }

      final nextSpecial = _nextSpecialIndex(rest);
      if (nextSpecial == 0) {
        output.add(_Segment(plain: rest[0]));
        index += 1;
        continue;
      }

      if (nextSpecial >= rest.length) {
        output.add(_Segment(plain: rest));
        break;
      }

      output.add(_Segment(plain: rest.substring(0, nextSpecial)));
      index += nextSpecial;
    }
  }

  static _MarkdownMatch? _tryMatch(
    String rest,
    RegExp pattern,
    TextEntityKind kind,
    int prefixLen,
    int suffixLen,
  ) {
    final match = pattern.firstMatch(rest);
    if (match == null) {
      return null;
    }
    final inner = match.group(1) ?? '';
    return _MarkdownMatch(
      inner: inner,
      kind: kind,
      fullLength: match.group(0)!.length,
    );
  }

  static _MarkdownMatch? _tryMatchLink(String rest) {
    final match = RegExp(r'^\[([^\]]+)\]\(([^)]+)\)').firstMatch(rest);
    if (match == null) {
      return null;
    }
    final label = match.group(1) ?? '';
    final url = match.group(2) ?? '';
    return _MarkdownMatch(
      inner: label,
      kind: TextEntityKind.textUrl,
      fullLength: match.group(0)!.length,
      url: url,
    );
  }

  static int _nextSpecialIndex(String rest) {
    final indexes = [
      rest.indexOf('**'),
      rest.indexOf('*'),
      rest.indexOf('_'),
      rest.indexOf('`'),
      rest.indexOf('['),
    ].where((value) => value >= 0);
    if (indexes.isEmpty) {
      return rest.length;
    }
    return indexes.reduce((a, b) => a < b ? a : b);
  }

  static List<TextEntity> _detectMentionsAndHashtags(
    String plain,
    List<TextEntity> existing,
  ) {
    final occupied = existing
        .map((entity) => (entity.offset, entity.offset + entity.length))
        .toList();

    bool isOccupied(int start, int end) {
      for (final range in occupied) {
        if (start < range.$2 && end > range.$1) {
          return true;
        }
      }
      return false;
    }

    final detected = <TextEntity>[];
    for (final match
        in RegExp(r'@(all|admins)\b', caseSensitive: false).allMatches(plain)) {
      if (!isOccupied(match.start, match.end)) {
        detected.add(
          TextEntity(
            offset: match.start,
            length: match.end - match.start,
            kind: TextEntityKind.mention,
          ),
        );
      }
    }
    for (final match in RegExp(r'@[\w\d_]{3,}').allMatches(plain)) {
      if (!isOccupied(match.start, match.end)) {
        detected.add(
          TextEntity(
            offset: match.start,
            length: match.end - match.start,
            kind: TextEntityKind.mention,
          ),
        );
      }
    }
    for (final match in RegExp(r'#[\w\d_]{2,}').allMatches(plain)) {
      if (!isOccupied(match.start, match.end)) {
        detected.add(
          TextEntity(
            offset: match.start,
            length: match.end - match.start,
            kind: TextEntityKind.hashtag,
          ),
        );
      }
    }
    return detected;
  }

  static List<TextEntity> _mergeEntities(List<TextEntity> entities) {
    final sorted = [...entities]..sort((a, b) {
        final byOffset = a.offset.compareTo(b.offset);
        if (byOffset != 0) {
          return byOffset;
        }
        return b.length.compareTo(a.length);
      });

    final result = <TextEntity>[];
    for (final entity in sorted) {
      final overlaps = result.any(
        (existing) =>
            entity.offset < existing.offset + existing.length &&
            entity.offset + entity.length > existing.offset,
      );
      if (!overlaps && entity.length > 0) {
        result.add(entity);
      }
    }
    return result;
  }
}

class _Segment {
  const _Segment({
    required this.plain,
    this.entities = const [],
  });

  final String plain;
  final List<TextEntity> entities;
}

class _MarkdownMatch {
  const _MarkdownMatch({
    required this.inner,
    required this.kind,
    required this.fullLength,
    this.url,
  });

  final String inner;
  final TextEntityKind kind;
  final int fullLength;
  final String? url;
}
