import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/call/call_manager.dart';
import '../core/call/group_call_manager.dart';
import '../core/theme/telegram_theme.dart';
import '../screens/call/call_screen.dart';

/// Глобальный полноэкранный оверлей звонка поверх основного UI (§9.8).
class CallOverlayHost extends StatelessWidget {
  const CallOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final callManager = context.watch<CallManager>();
    final groupCallManager = context.watch<GroupCallManager>();
    final showCall =
        callManager.hasActiveCall || groupCallManager.hasActiveGroupCall;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (showCall)
          const Positioned.fill(
            child: Material(
              color: TelegramColors.callBackground,
              child: CallScreen(),
            ),
          ),
      ],
    );
  }
}
