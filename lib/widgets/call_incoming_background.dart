import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../core/theme/telegram_theme.dart';
class CallIncomingBackground extends StatelessWidget {
  const CallIncomingBackground({super.key, required this.title, this.avatarLocalPath, this.colorKey});
  final String title; final String? avatarLocalPath; final String? colorKey;
  @override Widget build(BuildContext context) => Positioned.fill(child: Stack(fit: StackFit.expand, children: [
    _Backdrop(title: title, avatarLocalPath: avatarLocalPath, colorKey: colorKey),
    DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: .55), Colors.black.withValues(alpha: .82), Colors.black.withValues(alpha: .95)], stops: [0,.55,1]))),
  ]));
}
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.title, this.avatarLocalPath, this.colorKey});
  final String title; final String? avatarLocalPath; final String? colorKey;
  @override Widget build(BuildContext context) {
    final path = avatarLocalPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48), child: Transform.scale(scale: 1.35, child: Image.file(File(path), fit: BoxFit.cover, width: double.infinity, height: double.infinity)));
    }
    final color = TelegramAvatarColors.colorForKey(colorKey ?? title);
    return ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48), child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, .45)!])), child: Center(child: Text(TelegramAvatarColors.initialsForTitle(title), style: TextStyle(color: Colors.white.withValues(alpha: .35), fontSize: 180, fontWeight: FontWeight.w600)))));
  }
}
