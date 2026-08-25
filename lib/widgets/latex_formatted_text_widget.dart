import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../core/chat/latex_parser.dart';
import '../models/formatted_text.dart';
import 'formatted_text_widget.dart';

/// Текст сообщения с поддержкой LaTeX-формул.
class LatexFormattedTextWidget extends StatelessWidget {
  const LatexFormattedTextWidget({
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
    if (!LatexParser.containsLatex(formatted.text)) {
      return FormattedTextWidget(
        formatted: formatted,
        style: style,
        linkColor: linkColor,
      );
    }

    final segments = LatexParser.parse(formatted.text);
    final children = <Widget>[];

    for (final segment in segments) {
      switch (segment) {
        case LatexTextSegment(:final text):
          if (text.isEmpty) {
            continue;
          }
          children.add(
            FormattedTextWidget(
              formatted: FormattedText(text: text),
              style: style,
              linkColor: linkColor,
            ),
          );
        case LatexFormulaSegment(:final expression, :final isBlock):
          children.add(
            Padding(
              padding: EdgeInsets.symmetric(vertical: isBlock ? 6 : 0),
              child: _FormulaWidget(
                expression: expression,
                isBlock: isBlock,
                style: style,
              ),
            ),
          );
      }
    }

    if (children.length == 1) {
      return children.first;
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _FormulaWidget extends StatelessWidget {
  const _FormulaWidget({
    required this.expression,
    required this.isBlock,
    this.style,
  });

  final String expression;
  final bool isBlock;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = style ?? theme.textTheme.bodyMedium;
    try {
      final math = Math.tex(
        expression,
        mathStyle: isBlock ? MathStyle.display : MathStyle.text,
        textStyle: textStyle,
      );
      if (isBlock) {
        return Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: math,
          ),
        );
      }
      return math;
    } catch (_) {
      return Text(
        isBlock ? r'$$' '$expression' r'$$' : r'$' '$expression' r'$',
        style: textStyle?.copyWith(fontFamily: 'monospace'),
      );
    }
  }
}
