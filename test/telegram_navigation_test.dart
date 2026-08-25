import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/navigation/telegram_routes.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/widgets/chat_folder_sidebar.dart';
import 'package:riogram/widgets/mobile_tab_bar.dart';

void main() {
  group('TelegramLayoutBreakpoints', () {
    test('использует mobile 800px и three-column 840px', () {
      expect(TelegramLayoutBreakpoints.mobile, 800);
      expect(TelegramLayoutBreakpoints.threeColumn, 840);
      expect(TelegramLayoutBreakpoints.chatListWidth, 340);
      expect(TelegramLayoutBreakpoints.chatListWidthMin, 280);
    });
  });
  test('folder sidebar 68px', () => expect(ChatFolderSidebar.width, 68));

  group('TelegramNavigationDurations', () {
    test('переходы в диапазоне 150–200 ms', () {
      expect(TelegramNavigationDurations.push.inMilliseconds, 175);
      expect(TelegramNavigationDurations.fade.inMilliseconds, 175);
    });
  });

  group('TelegramPushRoute', () {
    test('задаёт длительность slide-перехода', () {
      final route = TelegramPushRoute<void>(builder: (_) => const SizedBox());
      expect(route.transitionDuration.inMilliseconds, 175);
    });
  });

  group('MobileTabBar', () {
    testWidgets('показывает три вкладки с outline-иконками', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TelegramTheme.build(brightness: Brightness.light),
          home: Scaffold(
            bottomNavigationBar: MobileTabBar(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Чаты'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble), findsNothing);
    });
  });

  group('TelegramTheme platform ink', () {
    test('задаёт pageTransitionsTheme и прозрачный splashColor', () {
      final theme = TelegramTheme.build(brightness: Brightness.light);
      expect(theme.splashColor, Colors.transparent);
      expect(theme.pageTransitionsTheme.builders, isNotEmpty);
    });
  });
}
