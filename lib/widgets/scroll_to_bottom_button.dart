import 'package:flutter/material.dart';
import '../core/theme/telegram_theme.dart';

class ScrollToBottomButton extends StatelessWidget {
  const ScrollToBottomButton({
    super.key,
    required this.newMessageCount,
    required this.onPressed,
  });
  final int newMessageCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (newMessageCount <= 0) return const SizedBox.shrink();
    final tg = context.telegramTheme;
    final label = newMessageCount == 1
        ? '1 новое сообщение'
        : '$newMessageCount новых сообщений';
    return Material(
      elevation: 0,
      color: tg.elevatedSurface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_downward, size: 16, color: tg.accent),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: TelegramFontSizes.preview,
                      color: tg.accent,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
