import 'package:flutter/foundation.dart';
// §9.11.9 regression — TelegramSettingsTile (no golden; CI headless).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/widgets/chat_avatar.dart';
import 'package:riogram/widgets/telegram_settings_tile.dart';

void main() {
  Widget wrap({required Widget child, double width = 390}) {
    return MaterialApp(
      theme: TelegramTheme.build(
        brightness: Brightness.light,
        fontFamily: TelegramTypography.desktopFontFamily,
      ),
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Scaffold(body: child),
      ),
    );
  }

  testWidgets('section header and tile', (tester) async {
    await tester.pumpWidget(
      wrap(
        child: Column(
          children: [
            const TelegramSettingsSectionHeader('Тема'),
            TelegramSettingsGroup(
              children: [
                TelegramSettingsTile(title: 'Прокси', value: 'Вкл', onTap: () {}, showDivider: false),
              ],
            ),
          ],
        ),
      ),
    );
    expect(find.text('ТЕМА'), findsOneWidget);
    expect(
      tester.getSize(find.byType(ConstrainedBox).first).height,
      greaterThanOrEqualTo(TelegramSpacing.settingsRowHeight),
    );
  });

  testWidgets('profile avatar 120px', (tester) async {
    await tester.pumpWidget(wrap(child: const TelegramProfileHeader(displayName: 'Alice')));
    expect(
      tester.widget<ChatAvatar>(find.byType(ChatAvatar)).radius,
      TelegramSpacing.profileScreenAvatarRadius,
    );
  });

  testWidgets('desktop flat list padding', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        wrap(width: 900, child: const TelegramSettingsListView(children: [SizedBox(height: 1)])),
      );
      expect(tester.widget<ListView>(find.byType(ListView)).padding, const EdgeInsets.fromLTRB(0, 8, 0, 24));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
