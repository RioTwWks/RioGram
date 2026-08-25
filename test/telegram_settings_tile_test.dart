// §9.11.9 regression — TelegramSettingsTile (no golden; CI headless).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/navigation/telegram_routes.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/widgets/telegram_settings_tile.dart';

void main() {
  testWidgets('settings tile and section header', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: TelegramTheme.build(brightness: Brightness.light),
      home: Scaffold(
        body: SizedBox(
          width: TelegramLayoutBreakpoints.mobile,
          child: Column(children: [
            const TelegramSettingsSectionHeader('Тема'),
            TelegramSettingsGroup(children: [
              TelegramSettingsTile(title: 'Прокси', value: 'Вкл', onTap: () {}),
            ]),
          ]),
        ),
      ),
    ));
    expect(find.text('ТЕМА'), findsOneWidget);
    expect(find.text('Прокси'), findsOneWidget);
    expect(TelegramSpacing.settingsRowHeight, 48);
  });
}
