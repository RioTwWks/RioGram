import 'package:flutter/material.dart';
import '../core/theme/telegram_theme.dart';
class ChatListResizeHandle extends StatefulWidget {
  const ChatListResizeHandle({super.key, required this.onDrag});
  final ValueChanged<double> onDrag;
  @override State<ChatListResizeHandle> createState() => _ChatListResizeHandleState();
}
class _ChatListResizeHandleState extends State<ChatListResizeHandle> {
  var _active = false;
  @override Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _active = true),
      onExit: (_) => setState(() => _active = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        child: SizedBox(width: TelegramSpacing.chatListResizeHandleWidth, child: Center(child: Container(width: _active ? 2 : 1, color: _active ? tg.accent : tg.chatListDivider))),
      ),
    );
  }
}
