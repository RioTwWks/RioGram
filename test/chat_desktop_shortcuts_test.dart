import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/widgets/chat_desktop_shortcuts.dart';

void main() {
  test('ChatDesktopShortcuts регистрирует поиск, новый чат и навигацию', () {
    expect(ChatDesktopShortcuts.shortcuts, isNotEmpty);
    expect(
      ChatDesktopShortcuts.shortcuts.values,
      contains(isA<FocusSearchIntent>()),
    );
    expect(
      ChatDesktopShortcuts.shortcuts.values,
      contains(isA<NewChatIntent>()),
    );
    expect(
      ChatDesktopShortcuts.shortcuts.values,
      contains(isA<PreviousChatIntent>()),
    );
    expect(
      ChatDesktopShortcuts.shortcuts.values,
      contains(isA<NextChatIntent>()),
    );
    expect(
      ChatDesktopShortcuts.shortcuts.keys,
      contains(const SingleActivator(LogicalKeyboardKey.keyF, control: true)),
    );
  });
}
