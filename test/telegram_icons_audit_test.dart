import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/theme/telegram_icons.dart';
import 'package:riogram/core/theme/telegram_theme.dart';

void main() {
  test('TelegramIcons audit §9.9', () {
    expect(TelegramIcons.reply, Icons.reply);
    expect(TelegramIcons.archive, Icons.archive_outlined);
    expect(TelegramIcons.size, 24);
  });
  test('dark theme flat §9.11.9', () {
    final theme = TelegramTheme.build(brightness: Brightness.dark);
    expect(theme.appBarTheme.elevation, 0);
  });
}
