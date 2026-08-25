/// Сегмент текста с формулой LaTeX или обычным текстом.
sealed class LatexSegment {
  const LatexSegment();
}

final class LatexTextSegment extends LatexSegment {
  const LatexTextSegment(this.text);

  final String text;
}

final class LatexFormulaSegment extends LatexSegment {
  const LatexFormulaSegment({
    required this.expression,
    required this.isBlock,
  });

  final String expression;
  final bool isBlock;
}

/// Парсер inline/block LaTeX в сообщениях.
abstract final class LatexParser {
  static final RegExp _inlineDollar = RegExp(r'(?<!\$)\$(?!\$)(.+?)(?<!\$)\$(?!\$)');
  static final RegExp _blockDollar = RegExp(r'\$\$(.+?)\$\$', dotAll: true);
  static final RegExp _inlineParen = RegExp(r'\\\((.+?)\\\)');
  static final RegExp _blockBracket = RegExp(r'\\\[(.+?)\\\]', dotAll: true);

  static List<LatexSegment> parse(String text) {
    if (text.isEmpty) {
      return const [LatexTextSegment('')];
    }

    final matches = <_LatexMatch>[];
    for (final pattern in [
      _blockDollar,
      _blockBracket,
      _inlineDollar,
      _inlineParen,
    ]) {
      for (final match in pattern.allMatches(text)) {
        final isBlock = pattern == _blockDollar || pattern == _blockBracket;
        matches.add(
          _LatexMatch(
            start: match.start,
            end: match.end,
            expression: match.group(1) ?? '',
            isBlock: isBlock,
          ),
        );
      }
    }

    if (matches.isEmpty) {
      return [LatexTextSegment(text)];
    }

    matches.sort((a, b) => a.start.compareTo(b.start));
    final filtered = <_LatexMatch>[];
    var cursor = -1;
    for (final match in matches) {
      if (match.start < cursor) {
        continue;
      }
      filtered.add(match);
      cursor = match.end;
    }

    final segments = <LatexSegment>[];
    var index = 0;
    for (final match in filtered) {
      if (match.start > index) {
        segments.add(LatexTextSegment(text.substring(index, match.start)));
      }
      segments.add(
        LatexFormulaSegment(
          expression: match.expression.trim(),
          isBlock: match.isBlock,
        ),
      );
      index = match.end;
    }
    if (index < text.length) {
      segments.add(LatexTextSegment(text.substring(index)));
    }
    return segments;
  }

  static bool containsLatex(String text) {
    return _blockDollar.hasMatch(text) ||
        _blockBracket.hasMatch(text) ||
        _inlineDollar.hasMatch(text) ||
        _inlineParen.hasMatch(text);
  }
}

final class _LatexMatch {
  const _LatexMatch({
    required this.start,
    required this.end,
    required this.expression,
    required this.isBlock,
  });

  final int start;
  final int end;
  final String expression;
  final bool isBlock;
}
