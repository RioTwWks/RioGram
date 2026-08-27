import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/media/web_avatar_cache.dart';
import '../core/theme/telegram_theme.dart';

/// Аватар чата: локальный файл, blob URL (web) или цветной placeholder.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.title,
    this.localPath,
    this.fileId,
    this.colorKey,
    this.radius = TelegramRadii.avatarList,
  });

  final String title;
  final String? localPath;
  final int? fileId;
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

    final placeholder = _buildPlaceholder();

    if (kIsWeb && fileId != null) {
      final cache = context.watch<WebAvatarCache?>();
      if (cache != null) {
        return _WebAvatarImage(
          fileId: fileId!,
          radius: radius,
          cache: cache,
          fallback: placeholder,
        );
      }
    }

    return placeholder;
  }

  Widget _buildPlaceholder() {
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

class _WebAvatarImage extends StatefulWidget {
  const _WebAvatarImage({
    required this.fileId,
    required this.radius,
    required this.cache,
    required this.fallback,
  });

  final int fileId;
  final double radius;
  final WebAvatarCache cache;
  final Widget fallback;

  @override
  State<_WebAvatarImage> createState() => _WebAvatarImageState();
}

class _WebAvatarImageState extends State<_WebAvatarImage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.cache.request(widget.fileId);
    });
  }

  @override
  void didUpdateWidget(covariant _WebAvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileId != widget.fileId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.cache.request(widget.fileId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.cache.urlFor(widget.fileId);
    if (url == null || url.isEmpty) {
      return widget.fallback;
    }
    return CircleAvatar(
      radius: widget.radius,
      backgroundImage: NetworkImage(url),
    );
  }
}
