import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/telegram_theme.dart';

/// Аватар чата: локальный файл или цветной placeholder с инициалами (как TG).
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.title,
    this.localPath,
    this.colorKey,
    this.radius = TelegramRadii.avatarList,
  });

  final String title;
  final String? localPath;
  final String? colorKey;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = localPath;
    if (!kIsWeb && path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return CircleAvatar(radius: radius, backgroundImage: FileImage(file));
      }
    }

    final key = colorKey ?? title;
    final initials = TelegramAvatarColors.initialsForTitle(title);
    final fontSize = radius < 28
        ? radius * 0.9
        : radius * (initials.length > 1 ? 0.72 : 0.85);

    return CircleAvatar(
      radius: radius,
      backgroundColor: TelegramAvatarColors.colorForKey(key),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
    );
  }
}
