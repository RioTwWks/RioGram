import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/widgets/chat_wallpaper.dart';

TelegramThemeData _themeWith({
  required Color chatBackground,
  required bool isDesktopChatBackground,
}) {
  return TelegramThemeData.light().copyWith(
    chatBackground: chatBackground,
    isDesktopChatBackground: isDesktopChatBackground,
  );
}

ThemeData _wrapTheme(TelegramThemeData tg, {Brightness brightness = Brightness.light}) {
  return TelegramTheme.build(brightness: brightness).copyWith(
    extensions: [tg],
  );
}

void main() {
  group('ChatWallpaper', () {
    testWidgets('рисуется без ошибок на mobile-фоне Android', (tester) async {
      final tg = _themeWith(
        chatBackground: TelegramColors.chatBackgroundLightAndroid,
        isDesktopChatBackground: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: _wrapTheme(tg),
          home: const Scaffold(body: ChatWallpaper()),
        ),
      );

      expect(find.byType(ChatWallpaper), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ChatWallpaper),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('рисуется на desktop с белым фоном', (tester) async {
      final tg = _themeWith(
        chatBackground: TelegramColors.chatBackgroundLightDesktop,
        isDesktopChatBackground: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: _wrapTheme(tg),
          home: const Scaffold(body: ChatWallpaper()),
        ),
      );

      expect(find.byType(ChatWallpaper), findsOneWidget);
    });

    testWidgets('рисуется в тёмной теме', (tester) async {
      final tg = _themeWith(
        chatBackground: TelegramColors.chatBackgroundDark,
        isDesktopChatBackground: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: _wrapTheme(tg, brightness: Brightness.dark),
          home: const Scaffold(body: ChatWallpaper()),
        ),
      );

      expect(find.byType(ChatWallpaper), findsOneWidget);
    });
  });
}
