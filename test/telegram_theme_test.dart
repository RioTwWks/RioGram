import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/core/theme/theme_manager.dart';

void main() {
  group('TelegramColors', () {
    test('содержит классические цвета светлой темы', () {
      expect(TelegramColors.accent, const Color(0xFF3390EC));
      expect(TelegramColors.chatListBackgroundLight, const Color(0xFFFFFFFF));
      expect(TelegramColors.chatListDividerLight, const Color(0xFFF0F0F0));
      expect(TelegramColors.chatBackgroundLightAndroid, const Color(0xFFE6EBEE));
      expect(TelegramColors.bubbleOutgoingLight, const Color(0xFFEFFEDE));
      expect(TelegramColors.bubbleIncomingLight, const Color(0xFFFFFFFF));
      expect(TelegramColors.textPrimaryLight, const Color(0xFF000000));
      expect(TelegramColors.textSecondaryLight, const Color(0xFF707579));
      expect(TelegramColors.textTimeLight, const Color(0xFF8E8E93));
    });

    test('содержит классические цвета тёмной темы', () {
      expect(TelegramColors.appBackgroundDark, const Color(0xFF17212B));
      expect(TelegramColors.chatListBackgroundDark, const Color(0xFF17212B));
      expect(TelegramColors.elevatedSurfaceDark, const Color(0xFF232E3C));
      expect(TelegramColors.bubbleOutgoingDark, const Color(0xFF2B5278));
      expect(TelegramColors.bubbleIncomingDark, const Color(0xFF182533));
      expect(TelegramColors.textPrimaryDark, const Color(0xFFFFFFFF));
    });
  });

  group('TelegramTypography', () {
    test('задаёт размеры как в Telegram', () {
      expect(TelegramFontSizes.chatTitle, 16);
      expect(TelegramFontSizes.message, 16);
      expect(TelegramFontSizes.preview, 14);
      expect(TelegramFontSizes.time, 12);
    });

    test('desktop использует Open Sans', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        expect(TelegramTypography.isDesktopPlatform, isTrue);
        expect(TelegramTypography.platformFontFamily!.toLowerCase(), contains('open'));
        final theme = TelegramTypography.textTheme(
          brightness: Brightness.light,
          primary: TelegramColors.textPrimaryLight,
          secondary: TelegramColors.textSecondaryLight,
          time: TelegramColors.textTimeLight,
        );
        expect(theme.bodyLarge?.fontFamily?.toLowerCase(), contains('open'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('textTheme использует semibold для заголовка чата', () {
      final theme = TelegramTypography.textTheme(
        brightness: Brightness.light,
        primary: TelegramColors.textPrimaryLight,
        secondary: TelegramColors.textSecondaryLight,
        time: TelegramColors.textTimeLight,
      );

      expect(theme.titleMedium?.fontSize, TelegramFontSizes.chatTitle);
      expect(theme.titleMedium?.fontWeight, FontWeight.w600);
      expect(theme.bodyLarge?.height, TelegramLineHeights.message);
    });
  });

  group('TelegramAvatarColors', () {
    test('детерминированный цвет по ключу', () {
      expect(
        TelegramAvatarColors.colorForKey('Alice'),
        TelegramAvatarColors.colorForKey('Alice'),
      );
      expect(
        TelegramAvatarColors.colorForKey('Alice'),
        isNot(equals(TelegramAvatarColors.colorForKey('Bob'))),
      );
    });

    test('инициалы из названия', () {
      expect(TelegramAvatarColors.initialsForTitle('Alice'), 'AL');
      expect(TelegramAvatarColors.initialsForTitle('Alice Smith'), 'AS');
      expect(TelegramAvatarColors.initialsForTitle(''), '?');
    });
  });

  group('TelegramRadii', () {
    test('задаёт плоские скругления без neumorphism', () {
      expect(TelegramRadii.bubble, 12);
      expect(TelegramRadii.bubbleLarge, 18);
      expect(TelegramRadii.avatarList, 24);
      expect(TelegramRadii.avatarGroup, 20);
      expect(TelegramRadii.buttonPill, 8);
      expect(TelegramRadii.inputField, 20);
    });
  });

  group('TelegramDesignConstraints', () {
    test('запрещает Liquid Glass паттерны', () {
      expect(TelegramDesignConstraints.allowBackdropBlur, isFalse);
      expect(TelegramDesignConstraints.allowTranslucentNavigation, isFalse);
      expect(TelegramDesignConstraints.allowDropShadows, isFalse);
      expect(TelegramDesignConstraints.allowGlassCapsules, isFalse);
    });
  });

  group('TelegramTheme', () {
    test('собирает светлую и тёмную ThemeData с extension', () {
      final light = TelegramTheme.build(brightness: Brightness.light);
      final dark = TelegramTheme.build(brightness: Brightness.dark);

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);

      final lightExt = light.extension<TelegramThemeData>();
      final darkExt = dark.extension<TelegramThemeData>();

      expect(lightExt, isNotNull);
      expect(darkExt, isNotNull);
      expect(lightExt!.bubbleOutgoing, TelegramColors.bubbleOutgoingLight);
      expect(darkExt!.bubbleOutgoing, TelegramColors.bubbleOutgoingDark);
    });

    test('AppBar и карточки без elevation/shadow', () {
      final theme = TelegramTheme.build(brightness: Brightness.light);

      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
      expect(theme.cardTheme.elevation, 0);
      expect(theme.cardTheme.shadowColor, Colors.transparent);
    });

    test('пузыри проходят WCAG AA по контрасту текста', () {
      final light = TelegramThemeData.light();
      final dark = TelegramThemeData.dark();

      expect(
        TelegramTheme.contrastRatio(
          light.bubbleOutgoingText,
          light.bubbleOutgoing,
        ),
        greaterThanOrEqualTo(TelegramTheme.wcagAaNormalText),
      );
      expect(
        TelegramTheme.contrastRatio(
          light.bubbleIncomingText,
          light.bubbleIncoming,
        ),
        greaterThanOrEqualTo(TelegramTheme.wcagAaNormalText),
      );
      expect(
        TelegramTheme.contrastRatio(
          dark.bubbleOutgoingText,
          dark.bubbleOutgoing,
        ),
        greaterThanOrEqualTo(TelegramTheme.wcagAaNormalText),
      );
      expect(
        TelegramTheme.contrastRatio(
          dark.bubbleIncomingText,
          dark.bubbleIncoming,
        ),
        greaterThanOrEqualTo(TelegramTheme.wcagAaNormalText),
      );
    });

    test('ThemeManager использует TelegramTheme', () {
      final manager = ThemeManager();

      expect(
        manager.lightTheme.extension<TelegramThemeData>(),
        isNotNull,
      );
      expect(
        manager.darkTheme.extension<TelegramThemeData>(),
        isNotNull,
      );
      expect(
        manager.lightTheme.colorScheme.primary,
        TelegramColors.accent,
      );
    });
  });
}
