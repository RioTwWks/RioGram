import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:riogram/core/navigation/telegram_routes.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/core/theme/ui_customization_manager.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:riogram/widgets/chat_folder_sidebar.dart';
import 'package:riogram/widgets/empty_state.dart';

void main() {
  testWidgets('desktop shell 800/840 без overflow', (tester) async {
    for (final width in [800.0, 840.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => UiCustomizationManager(),
        child: MaterialApp(
          theme: TelegramTheme.build(brightness: Brightness.light),
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, 900)),
            child: Scaffold(body: Row(children: [
              ChatFolderSidebar(activeList: const ChatListMain(), folders: const [], onSelected: (_) {}, onSettings: () {}),
              SizedBox(width: TelegramLayoutBreakpoints.chatListWidth, child: const EmptyStateWidget(illustration: EmptyStateIllustration.noChats, title: 'Нет чатов')),
              const Expanded(child: EmptyStateWidget(illustration: EmptyStateIllustration.selectChat, title: 'Выберите чат')),
            ])),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
