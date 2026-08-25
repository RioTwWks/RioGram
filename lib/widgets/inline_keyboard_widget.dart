import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/message_enrichment.dart';

/// Inline-клавиатура под сообщением.
class InlineKeyboardWidget extends StatelessWidget {
  const InlineKeyboardWidget({
    super.key,
    required this.rows,
    this.onCallbackTap,
    this.onWebAppTap,
    this.onSwitchInlineTap,
  });

  final List<List<InlineKeyboardButtonModel>> rows;
  final void Function(InlineKeyboardButtonModel button)? onCallbackTap;
  final void Function(InlineKeyboardButtonModel button)? onWebAppTap;
  final void Function(InlineKeyboardButtonModel button)? onSwitchInlineTap;

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

  Future<void> _handleTap(
    BuildContext context,
    InlineKeyboardButtonModel button,
  ) async {
    switch (button.kind) {
      case InlineKeyboardButtonKind.url:
      case InlineKeyboardButtonKind.loginUrl:
        final url = button.url;
        if (url != null && url.isNotEmpty) {
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Не удалось открыть: $url')),
            );
          }
        }
      case InlineKeyboardButtonKind.copyText:
        final text = button.copyText ?? button.text;
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Текст скопирован')),
          );
        }
      case InlineKeyboardButtonKind.webApp:
        onWebAppTap?.call(button);
      case InlineKeyboardButtonKind.switchInline:
        onSwitchInlineTap?.call(button);
      case InlineKeyboardButtonKind.callback:
      case InlineKeyboardButtonKind.callbackWithPassword:
      case InlineKeyboardButtonKind.game:
      case InlineKeyboardButtonKind.buy:
        onCallbackTap?.call(button);
      case InlineKeyboardButtonKind.user:
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                button.userId != null
                    ? 'Пользователь ${button.userId}'
                    : button.text,
              ),
            ),
          );
        }
      case InlineKeyboardButtonKind.unknown:
        if (button.url != null && button.url!.isNotEmpty) {
          final uri = Uri.tryParse(button.url!);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } else {
          onCallbackTap?.call(button);
        }
    }
  }
}
