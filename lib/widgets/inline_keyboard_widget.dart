import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/message_enrichment.dart';

/// Inline-клавиатура под сообщением.
class InlineKeyboardWidget extends StatelessWidget {
  const InlineKeyboardWidget({
    super.key,
    required this.rows,
    this.onCallbackTap,
  });

  final List<List<InlineKeyboardButtonModel>> rows;
  final void Function(InlineKeyboardButtonModel button)? onCallbackTap;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: row.map((button) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: OutlinedButton(
                    onPressed: () => _handleTap(context, button),
                    child: Text(
                      button.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  void _handleTap(BuildContext context, InlineKeyboardButtonModel button) {
    if (button.url != null && button.url!.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: button.url!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ссылка скопирована: ${button.url}')),
      );
      return;
    }

    if (button.callbackData != null && onCallbackTap != null) {
      onCallbackTap!(button);
    }
  }
}
