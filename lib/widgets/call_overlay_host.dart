import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/call/call_manager.dart';
import '../screens/call/call_screen.dart';

/// Глобальный оверлей звонка поверх основного UI.
class CallOverlayHost extends StatelessWidget {
  const CallOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer<CallManager>(
      builder: (context, callManager, _) {
        final showCall = callManager.hasActiveCall;
        return Stack(
          children: [
            child,
            if (showCall)
              const Positioned.fill(
                child: CallScreen(),
              ),
          ],
        );
      },
    );
  }
}
