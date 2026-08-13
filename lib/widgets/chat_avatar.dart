import 'dart:io';

import 'package:flutter/material.dart';

/// Аватар чата: локальный файл или буква из названия.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.title,
    this.localPath,
    this.radius = 20,
  });

  final String title;
  final String? localPath;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = localPath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: FileImage(file),
        );
      }
    }

    final letter = title.trim().isNotEmpty ? title.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      child: Text(letter),
    );
  }
}
