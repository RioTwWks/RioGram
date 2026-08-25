import 'package:flutter/material.dart';

import '../models/story_models.dart';
import 'chat_avatar.dart';

/// Аватар с цветным кольцом непросмотренных историй.
class StoryAvatarRing extends StatelessWidget {
  const StoryAvatarRing({
    super.key,
    required this.title,
    this.localPath,
    required this.readState,
    this.radius = 28,
    this.onTap,
  });

  final String title;
  final String? localPath;
  final StoryReadState readState;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ringColors = _ringColors(context);
    final child = Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ringColors == null
            ? null
            : LinearGradient(
                colors: ringColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: ringColors == null
            ? Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1.5,
              )
            : null,
      ),
      child: ChatAvatar(
        title: title,
        localPath: localPath,
        radius: radius,
      ),
    );

    if (onTap == null) {
      return child;
    }
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: child,
    );
  }

  List<Color>? _ringColors(BuildContext context) {
    return switch (readState) {
      StoryReadState.unread => const [Color(0xFF6C5CE7), Color(0xFFFD79A8)],
      StoryReadState.live => const [Color(0xFFFF7675), Color(0xFFFFD93D)],
      StoryReadState.read => [
          Theme.of(context).colorScheme.outline,
          Theme.of(context).colorScheme.outlineVariant,
        ],
      StoryReadState.none => null,
    };
  }
}
