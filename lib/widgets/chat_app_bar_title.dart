import 'package:flutter/material.dart';
import '../core/theme/telegram_theme.dart';
import '../models/user_models.dart';
import 'chat_avatar.dart';
import 'user_status_subtitle.dart';

class ChatAppBarTitle extends StatelessWidget {
  const ChatAppBarTitle({
    super.key,
    required this.title,
    this.avatarLocalPath,
    this.userStatus,
    this.typingStatus,
    this.subtitle,
    this.onTap,
  });
  final String title;
  final String? avatarLocalPath;
  final UserStatusInfo? userStatus;
  final String? typingStatus;
  final Widget? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    Widget status;
    if (typingStatus != null && typingStatus!.isNotEmpty) {
      status = Text(typingStatus!,
          style: TextStyle(
              fontSize: TelegramFontSizes.chatSubtitle, color: tg.accent),
          maxLines: 1,
          overflow: TextOverflow.ellipsis);
    } else if (subtitle != null) {
      status = subtitle!;
    } else if (userStatus != null) {
      status = UserStatusSubtitle(
        status: userStatus!,
        style: TextStyle(
            fontSize: TelegramFontSizes.chatSubtitle, color: tg.textSecondary),
      );
    } else {
      status = const SizedBox.shrink();
    }
    final content = Row(
      children: [
        ChatAvatar(
            title: title,
            localPath: avatarLocalPath,
            radius: TelegramSpacing.avatarGroup / 2),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: TelegramFontSizes.chatTitle,
                      fontWeight: FontWeight.w600,
                      color: tg.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              status,
            ],
          ),
        ),
      ],
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}

class ChatAppBarKindSubtitle extends StatelessWidget {
  const ChatAppBarKindSubtitle({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
  });
  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor ?? tg.accent),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: TelegramFontSizes.chatSubtitle,
                color: tg.textSecondary)),
      ],
    );
  }
}
