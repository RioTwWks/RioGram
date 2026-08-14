import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/formatted_text.dart';

/// Отображение formattedText с entities TDLib.
class FormattedTextWidget extends StatelessWidget {
  const FormattedTextWidget({
    super.key,
    required this.formatted,
    this.style,
    this.linkColor,
  });

  final FormattedText formatted;
  final TextStyle? style;
  final Color? linkColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = style ?? theme.textTheme.bodyMedium;
    final linkStyle = baseStyle?.copyWith(
      color: linkColor ?? theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    if (formatted.entities.isEmpty) {
      return Text(formatted.text, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final entity in formatted.entities) {
      if (entity.offset > cursor) {
        spans.add(TextSpan(
          text: _slice(formatted.text, cursor, entity.offset),
          style: baseStyle,
        ));
      }

      final end = entity.offset + entity.length;
      final entityText = _slice(formatted.text, entity.offset, end);
      spans.add(
        TextSpan(
          text: entityText,
          style: _styleForEntity(entity, entityText, baseStyle, linkStyle),
          recognizer: _recognizerForEntity(entity, entityText),
        ),
      );
      cursor = end;
    }

    if (cursor < formatted.text.length) {
      spans.add(TextSpan(
        text: _slice(formatted.text, cursor, formatted.text.length),
        style: baseStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  static String _slice(String text, int start, int end) {
    if (start >= text.length) {
      return '';
    }
    final safeEnd = end.clamp(0, text.length);
    return text.substring(start, safeEnd);
  }

  TextStyle? _styleForEntity(
    TextEntity entity,
    String entityText,
    TextStyle? base,
    TextStyle? link,
  ) {
    return switch (entity.kind) {
      TextEntityKind.bold => base?.copyWith(fontWeight: FontWeight.bold),
      TextEntityKind.italic => base?.copyWith(fontStyle: FontStyle.italic),
      TextEntityKind.code => base?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: Colors.black12,
        ),
      TextEntityKind.url ||
      TextEntityKind.textUrl ||
      TextEntityKind.mention ||
      TextEntityKind.mentionName ||
      TextEntityKind.hashtag =>
        _isBroadcastMention(entityText)
            ? base?.copyWith(
                fontWeight: FontWeight.bold,
                color: link?.color ?? base.color,
              )
            : link,
    };
  }

  static bool _isBroadcastMention(String text) {
    final lower = text.toLowerCase();
    return lower == '@all' || lower == '@admins';
  }

  TapGestureRecognizer? _recognizerForEntity(TextEntity entity, String label) {
    final url = switch (entity.kind) {
      TextEntityKind.url => label,
      TextEntityKind.textUrl => entity.url,
      _ => null,
    };
    if (url == null || url.isEmpty) {
      return null;
    }
    return TapGestureRecognizer()..onTap = () {};
  }
}
