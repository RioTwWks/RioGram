import 'package:flutter/material.dart';
import '../core/theme/telegram_icons.dart';
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
      shape: StadiumBorder(
        side: BorderSide(color: tg.chatListDivider.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TelegramSpacing.scrollToBottomHorizontalPadding,
            vertical: TelegramSpacing.scrollToBottomVerticalPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(TelegramIcons.arrowDown, size: 16, color: tg.accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: TelegramFontSizes.preview,
                  color: tg.accent,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
