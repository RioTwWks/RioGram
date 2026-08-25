import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/navigation/telegram_routes.dart';
import 'package:riogram/core/theme/telegram_theme.dart';

void main() {
  group('TelegramDesignConstraints §9.11', () {
    test('запрещает Liquid Glass паттерны', () {
      expect(TelegramDesignConstraints.allowBackdropBlur, isFalse);
      expect(TelegramDesignConstraints.allowTranslucentNavigation, isFalse);
      expect(TelegramDesignConstraints.allowDropShadows, isFalse);
      expect(TelegramDesignConstraints.allowGlassCapsules, isFalse);
    });
  });

  group('TelegramSpacing §9.11 row heights', () {
    test('задаёт целевые высоты строк Telegram', () {
      expect(TelegramSpacing.chatListRowHeight, 72);
      expect(TelegramSpacing.chatAppBarHeight, 56);
      expect(TelegramSpacing.settingsRowHeight, 48);
      expect(TelegramSpacing.chatListHorizontalPadding, 12);
      expect(TelegramSpacing.folderSidebarWidth, 68);
      expect(TelegramSpacing.callControlSpacing, 24);
    });

    test('avatar + inset совпадают с TG chat list', () {
      expect(TelegramSpacing.avatarList, 48);
      expect(
        TelegramSpacing.chatListDividerInset,
        TelegramSpacing.chatListHorizontalPadding +
            TelegramSpacing.avatarList +
            12,
      );
    });
  });

  group('TelegramLayoutBreakpoints §9.11', () {
    test('mobile и three-column breakpoints', () {
      expect(TelegramLayoutBreakpoints.mobile, 800);
      expect(TelegramLayoutBreakpoints.threeColumn, 840);
      expect(TelegramLayoutBreakpoints.chatListWidth, 340);
      expect(TelegramLayoutBreakpoints.chatListWidthMin, 280);
      expect(TelegramLayoutBreakpoints.chatListWidthMax, 480);
    });
  });

  group('TelegramNavigationDurations §9.11', () {
    test('переходы 150–200 ms', () {
      expect(TelegramNavigationDurations.push.inMilliseconds, 175);
      expect(TelegramNavigationDurations.fade.inMilliseconds, 175);
    });
  });

  group('TelegramRadii §9.11', () {
    test('плоские скругления пузырей и полей', () {
      expect(TelegramRadii.bubble, 12);
      expect(TelegramRadii.bubbleLarge, 18);
      expect(TelegramRadii.inputField, 20);
      expect(TelegramRadii.unreadBadge, 10);
    });
  });

  group('TelegramFontSizes §9.11', () {
    test('типографика сообщений и preview', () {
      expect(TelegramFontSizes.chatTitle, 16);
      expect(TelegramFontSizes.message, 16);
      expect(TelegramFontSizes.preview, 14);
      expect(TelegramFontSizes.time, 12);
      expect(TelegramFontSizes.bubbleMeta, 11);
    });
  });

  group('TelegramColors date separator §9.11', () {
    test('capsule opacity как в TG (#0000004D)', () {
      expect(TelegramColors.dateSeparatorBackgroundLight, const Color(0x4D000000));
    });
  });

  group('TelegramTheme flat surfaces §9.11', () {
    test('AppBar и карточки без elevation', () {
      final theme = TelegramTheme.build(brightness: Brightness.light);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.cardTheme.elevation, 0);
      expect(theme.cardTheme.shadowColor, Colors.transparent);
    });
  });
}
