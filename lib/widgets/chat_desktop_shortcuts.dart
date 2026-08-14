import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Intent для горячих клавиш десктопного экрана чатов.
final class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

final class NewChatIntent extends Intent {
  const NewChatIntent();
}

final class PreviousChatIntent extends Intent {
  const PreviousChatIntent();
}

final class NextChatIntent extends Intent {
  const NextChatIntent();
}

/// Обёртка Shortcuts/Actions для навигации как в Telegram Desktop.
class ChatDesktopShortcuts extends StatelessWidget {
  const ChatDesktopShortcuts({
    super.key,
    required this.child,
    required this.onFocusSearch,
    required this.onNewChat,
    required this.onPreviousChat,
    required this.onNextChat,
  });

  final Widget child;
  final VoidCallback onFocusSearch;
  final VoidCallback onNewChat;
  final VoidCallback onPreviousChat;
  final VoidCallback onNextChat;

  static const shortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.keyF, control: true): FocusSearchIntent(),
    SingleActivator(LogicalKeyboardKey.keyF, meta: true): FocusSearchIntent(),
    SingleActivator(LogicalKeyboardKey.keyK, control: true): FocusSearchIntent(),
    SingleActivator(LogicalKeyboardKey.keyK, meta: true): FocusSearchIntent(),
    SingleActivator(LogicalKeyboardKey.keyN, control: true): NewChatIntent(),
    SingleActivator(LogicalKeyboardKey.keyN, meta: true): NewChatIntent(),
    SingleActivator(LogicalKeyboardKey.arrowUp, control: true): PreviousChatIntent(),
    SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): PreviousChatIntent(),
    SingleActivator(LogicalKeyboardKey.arrowDown, control: true): NextChatIntent(),
    SingleActivator(LogicalKeyboardKey.arrowDown, meta: true): NextChatIntent(),
    SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): PreviousChatIntent(),
    SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): NextChatIntent(),
  };

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          FocusSearchIntent: CallbackAction<FocusSearchIntent>(
            onInvoke: (_) {
              onFocusSearch();
              return null;
            },
          ),
          NewChatIntent: CallbackAction<NewChatIntent>(
            onInvoke: (_) {
              onNewChat();
              return null;
            },
          ),
          PreviousChatIntent: CallbackAction<PreviousChatIntent>(
            onInvoke: (_) {
              onPreviousChat();
              return null;
            },
          ),
          NextChatIntent: CallbackAction<NextChatIntent>(
            onInvoke: (_) {
              onNextChat();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}
