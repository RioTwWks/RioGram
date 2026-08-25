import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../navigation/telegram_routes.dart';

/// Классический Telegram (до Liquid Glass): палитра, типографика, радиусы.
///
/// Референс: Telegram Desktop 4.x–5.x, Android/iOS до frosted-glass редизайна.
abstract final class TelegramColors {
  /// Акцент / ссылки — классический Telegram blue.
  static const Color accent = Color(0xFF3390EC);

  // --- Светлая тема ---

  static const Color chatListBackgroundLight = Color(0xFFFFFFFF);
  static const Color chatListDividerLight = Color(0xFFF0F0F0);
  static const Color chatBackgroundLightAndroid = Color(0xFFE6EBEE);
  static const Color chatBackgroundLightDesktop = Color(0xFFFFFFFF);

  static const Color bubbleOutgoingLight = Color(0xFFEFFEDE);
  static const Color bubbleIncomingLight = Color(0xFFFFFFFF);

  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textSecondaryLight = Color(0xFF707579);
  static const Color textTimeLight = Color(0xFF8E8E93);

  static const Color inputFieldBackgroundLight = Color(0xFFF0F0F0);
  static const Color searchFieldBackgroundLight = Color(0xFFF0F0F0);
  static const Color dateSeparatorBackgroundLight = Color(0x29000000);

  // --- Тёмная тема ---

  static const Color appBackgroundDark = Color(0xFF17212B);
  static const Color chatListBackgroundDark = Color(0xFF17212B);
  static const Color elevatedSurfaceDark = Color(0xFF232E3C);
  static const Color chatBackgroundDark = Color(0xFF0E1621);

  static const Color bubbleOutgoingDark = Color(0xFF2B5278);
  static const Color bubbleIncomingDark = Color(0xFF182533);

  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF707579);
  static const Color textTimeDark = Color(0xFF8E8E93);

  static const Color inputFieldBackgroundDark = Color(0xFF242F3D);
  static const Color searchFieldBackgroundDark = Color(0xFF242F3D);
  static const Color dateSeparatorBackgroundDark = Color(0x33FFFFFF);

  static const Color unreadBadgeText = Color(0xFFFFFFFF);

  // --- Звонки (§9.8) ---

  /// Полноэкранный фон активного / входящего звонка.
  static const Color callBackground = Color(0xFF000000);

  static const Color callTextPrimary = Color(0xFFFFFFFF);
  static const Color callTextSecondary = Color(0xFFAAAAAA);

  /// Кнопка «Принять» на входящем звонке.
  static const Color callAcceptGreen = Color(0xFF4CB050);

  /// Кнопка «Отклонить» / завершить звонок.
  static const Color callDeclineRed = Color(0xFFE53935);

  /// Фон круглых кнопок управления на активном звонке.
  static const Color callControlBackground = Color(0x33FFFFFF);
}

/// Размеры шрифтов в стиле Telegram.
abstract final class TelegramFontSizes {
  static const double chatTitle = 16;
  static const double message = 16;
  static const double preview = 14;
  static const double time = 12;
  static const double sectionHeader = 12;
  static const double chatSubtitle = 13;
  static const double bubbleMeta = 11;
}

/// Межстрочные интервалы.
abstract final class TelegramLineHeights {
  static const double message = 1.25;
  static const double preview = 1.3;
  static const double chatTitle = 1.2;
}

/// Скругления — плоский стиль, без neumorphism.
abstract final class TelegramRadii {
  static const double bubble = 12;
  static const double bubbleLarge = 18;
  static const double bubbleGrouped = 6;
  static const double avatarList = 24;
  static const double avatarGroup = 20;
  static const double buttonPill = 8;
  static const double inputField = 20;
  static const double searchField = 10;
  static const double mediaPreview = 8;
  static const double unreadBadge = 10;
}

/// Отступы и размеры компонентов.
abstract final class TelegramSpacing {
  static const double avatarList = 48;
  static const double avatarGroup = 40;
  static const double chatListDividerInset = 72;
  static const double unreadBadgeMinWidth = 20;
  static const double unreadBadgeMinHeight = 20;

  /// §9.8 — звонки.
  static const double callAvatarRadius = 60;
  static const double callPrimaryButtonSize = 72;
  static const double callControlButtonSize = 64;
}

/// Платформенный шрифт как у Telegram.
abstract final class TelegramTypography {
  static String? get platformFontFamily {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => '.AppleSystemUIFont',
      TargetPlatform.android => 'Roboto',
      _ => null,
    };
  }

  static TextTheme textTheme({
    required Brightness brightness,
    required Color primary,
    required Color secondary,
    required Color time,
  }) {
    final family = platformFontFamily;
    final base = brightness == Brightness.light
        ? Typography.material2021(platform: TargetPlatform.android).black
        : Typography.material2021(platform: TargetPlatform.android).white;

    TextStyle styled(
      TextStyle? style, {
      required double size,
      FontWeight weight = FontWeight.w400,
      double? height,
      Color? color,
    }) {
      return (style ?? const TextStyle()).copyWith(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color,
      );
    }

    return base.copyWith(
      titleLarge: styled(
        base.titleLarge,
        size: TelegramFontSizes.chatTitle,
        weight: FontWeight.w600,
        height: TelegramLineHeights.chatTitle,
        color: primary,
      ),
      titleMedium: styled(
        base.titleMedium,
        size: TelegramFontSizes.chatTitle,
        weight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: styled(
        base.bodyLarge,
        size: TelegramFontSizes.message,
        height: TelegramLineHeights.message,
        color: primary,
      ),
      bodyMedium: styled(
        base.bodyMedium,
        size: TelegramFontSizes.preview,
        height: TelegramLineHeights.preview,
        color: secondary,
      ),
      bodySmall: styled(
        base.bodySmall,
        size: TelegramFontSizes.chatSubtitle,
        color: secondary,
      ),
      labelMedium: styled(
        base.labelMedium,
        size: TelegramFontSizes.chatSubtitle,
        weight: FontWeight.w600,
        color: primary,
      ),
      labelSmall: styled(
        base.labelSmall,
        size: TelegramFontSizes.time,
        color: time,
      ),
    );
  }
}

/// Семантические цвета UI, недоступные через стандартный [ColorScheme].
@immutable
class TelegramThemeData extends ThemeExtension<TelegramThemeData> {
  const TelegramThemeData({
    required this.chatListBackground,
    required this.chatListDivider,
    required this.chatBackground,
    required this.bubbleOutgoing,
    required this.bubbleIncoming,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTime,
    required this.elevatedSurface,
    required this.inputFieldBackground,
    required this.searchFieldBackground,
    required this.dateSeparatorBackground,
    required this.unreadBadgeBackground,
    required this.unreadBadgeText,
    required this.bubbleOutgoingText,
    required this.bubbleIncomingText,
    required this.accent,
    required this.isDesktopChatBackground,
  });

  final Color chatListBackground;
  final Color chatListDivider;
  final Color chatBackground;
  final Color bubbleOutgoing;
  final Color bubbleIncoming;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTime;
  final Color elevatedSurface;
  final Color inputFieldBackground;
  final Color searchFieldBackground;
  final Color dateSeparatorBackground;
  final Color unreadBadgeBackground;
  final Color unreadBadgeText;
  final Color bubbleOutgoingText;
  final Color bubbleIncomingText;
  final Color accent;
  final bool isDesktopChatBackground;

  static TelegramThemeData light({Color accentColor = TelegramColors.accent}) {
    final isDesktop = _isDesktopPlatform;
    return TelegramThemeData(
      chatListBackground: TelegramColors.chatListBackgroundLight,
      chatListDivider: TelegramColors.chatListDividerLight,
      chatBackground: isDesktop
          ? TelegramColors.chatBackgroundLightDesktop
          : TelegramColors.chatBackgroundLightAndroid,
      bubbleOutgoing: TelegramColors.bubbleOutgoingLight,
      bubbleIncoming: TelegramColors.bubbleIncomingLight,
      textPrimary: TelegramColors.textPrimaryLight,
      textSecondary: TelegramColors.textSecondaryLight,
      textTime: TelegramColors.textTimeLight,
      elevatedSurface: TelegramColors.chatListBackgroundLight,
      inputFieldBackground: TelegramColors.inputFieldBackgroundLight,
      searchFieldBackground: TelegramColors.searchFieldBackgroundLight,
      dateSeparatorBackground: TelegramColors.dateSeparatorBackgroundLight,
      unreadBadgeBackground: accentColor,
      unreadBadgeText: TelegramColors.unreadBadgeText,
      bubbleOutgoingText: TelegramColors.textPrimaryLight,
      bubbleIncomingText: TelegramColors.textPrimaryLight,
      accent: accentColor,
      isDesktopChatBackground: isDesktop,
    );
  }

  static TelegramThemeData dark({Color accentColor = TelegramColors.accent}) {
    return TelegramThemeData(
      chatListBackground: TelegramColors.chatListBackgroundDark,
      chatListDivider: TelegramColors.elevatedSurfaceDark,
      chatBackground: TelegramColors.chatBackgroundDark,
      bubbleOutgoing: TelegramColors.bubbleOutgoingDark,
      bubbleIncoming: TelegramColors.bubbleIncomingDark,
      textPrimary: TelegramColors.textPrimaryDark,
      textSecondary: TelegramColors.textSecondaryDark,
      textTime: TelegramColors.textTimeDark,
      elevatedSurface: TelegramColors.elevatedSurfaceDark,
      inputFieldBackground: TelegramColors.inputFieldBackgroundDark,
      searchFieldBackground: TelegramColors.searchFieldBackgroundDark,
      dateSeparatorBackground: TelegramColors.dateSeparatorBackgroundDark,
      unreadBadgeBackground: accentColor,
      unreadBadgeText: TelegramColors.unreadBadgeText,
      bubbleOutgoingText: TelegramColors.textPrimaryDark,
      bubbleIncomingText: TelegramColors.textPrimaryDark,
      accent: accentColor,
      isDesktopChatBackground: _isDesktopPlatform,
    );
  }

  static bool get _isDesktopPlatform {
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS =>
        true,
      _ => false,
    };
  }

  @override
  TelegramThemeData copyWith({
    Color? chatListBackground,
    Color? chatListDivider,
    Color? chatBackground,
    Color? bubbleOutgoing,
    Color? bubbleIncoming,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTime,
    Color? elevatedSurface,
    Color? inputFieldBackground,
    Color? searchFieldBackground,
    Color? dateSeparatorBackground,
    Color? unreadBadgeBackground,
    Color? unreadBadgeText,
    Color? bubbleOutgoingText,
    Color? bubbleIncomingText,
    Color? accent,
    bool? isDesktopChatBackground,
  }) {
    return TelegramThemeData(
      chatListBackground: chatListBackground ?? this.chatListBackground,
      chatListDivider: chatListDivider ?? this.chatListDivider,
      chatBackground: chatBackground ?? this.chatBackground,
      bubbleOutgoing: bubbleOutgoing ?? this.bubbleOutgoing,
      bubbleIncoming: bubbleIncoming ?? this.bubbleIncoming,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTime: textTime ?? this.textTime,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      inputFieldBackground:
          inputFieldBackground ?? this.inputFieldBackground,
      searchFieldBackground:
          searchFieldBackground ?? this.searchFieldBackground,
      dateSeparatorBackground:
          dateSeparatorBackground ?? this.dateSeparatorBackground,
      unreadBadgeBackground:
          unreadBadgeBackground ?? this.unreadBadgeBackground,
      unreadBadgeText: unreadBadgeText ?? this.unreadBadgeText,
      bubbleOutgoingText: bubbleOutgoingText ?? this.bubbleOutgoingText,
      bubbleIncomingText: bubbleIncomingText ?? this.bubbleIncomingText,
      accent: accent ?? this.accent,
      isDesktopChatBackground:
          isDesktopChatBackground ?? this.isDesktopChatBackground,
    );
  }

  @override
  TelegramThemeData lerp(ThemeExtension<TelegramThemeData>? other, double t) {
    if (other is! TelegramThemeData) {
      return this;
    }
    return TelegramThemeData(
      chatListBackground:
          Color.lerp(chatListBackground, other.chatListBackground, t)!,
      chatListDivider: Color.lerp(chatListDivider, other.chatListDivider, t)!,
      chatBackground: Color.lerp(chatBackground, other.chatBackground, t)!,
      bubbleOutgoing: Color.lerp(bubbleOutgoing, other.bubbleOutgoing, t)!,
      bubbleIncoming: Color.lerp(bubbleIncoming, other.bubbleIncoming, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTime: Color.lerp(textTime, other.textTime, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      inputFieldBackground:
          Color.lerp(inputFieldBackground, other.inputFieldBackground, t)!,
      searchFieldBackground:
          Color.lerp(searchFieldBackground, other.searchFieldBackground, t)!,
      dateSeparatorBackground: Color.lerp(
        dateSeparatorBackground,
        other.dateSeparatorBackground,
        t,
      )!,
      unreadBadgeBackground:
          Color.lerp(unreadBadgeBackground, other.unreadBadgeBackground, t)!,
      unreadBadgeText: Color.lerp(unreadBadgeText, other.unreadBadgeText, t)!,
      bubbleOutgoingText:
          Color.lerp(bubbleOutgoingText, other.bubbleOutgoingText, t)!,
      bubbleIncomingText:
          Color.lerp(bubbleIncomingText, other.bubbleIncomingText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      isDesktopChatBackground: t < 0.5
          ? isDesktopChatBackground
          : other.isDesktopChatBackground,
    );
  }
}

/// Анти-паттерны Liquid Glass — не использовать в UI §9.
abstract final class TelegramDesignConstraints {
  /// Запрет blur-панелей (`BackdropFilter`, `ImageFilter.blur`).
  static const bool allowBackdropBlur = false;

  /// Запрет полупрозрачных AppBar / tab bar.
  static const bool allowTranslucentNavigation = false;

  /// Запрет drop-shadow у пузырей и карточек.
  static const bool allowDropShadows = false;

  /// Запрет neumorphism и «стеклянных» капсул iOS 26.
  static const bool allowGlassCapsules = false;
}

/// Сборка [ThemeData] в классическом стиле Telegram.
abstract final class TelegramTheme {
  static ThemeData build({
    required Brightness brightness,
    Color accentColor = TelegramColors.accent,
  }) {
    final telegram = brightness == Brightness.light
        ? TelegramThemeData.light(accentColor: accentColor)
        : TelegramThemeData.dark(accentColor: accentColor);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: telegram.accent,
      onPrimary: TelegramColors.unreadBadgeText,
      secondary: telegram.textSecondary,
      onSecondary: telegram.textPrimary,
      error: const Color(0xFFE53935),
      onError: TelegramColors.unreadBadgeText,
      surface: telegram.chatListBackground,
      onSurface: telegram.textPrimary,
      surfaceContainerHighest: telegram.elevatedSurface,
      onSurfaceVariant: telegram.textSecondary,
      outline: telegram.chatListDivider,
      outlineVariant: telegram.chatListDivider,
      primaryContainer: telegram.bubbleOutgoing,
      onPrimaryContainer: telegram.bubbleOutgoingText,
      secondaryContainer: telegram.bubbleIncoming,
      onSecondaryContainer: telegram.bubbleIncomingText,
    );

    final textTheme = TelegramTypography.textTheme(
      brightness: brightness,
      primary: telegram.textPrimary,
      secondary: telegram.textSecondary,
      time: telegram.textTime,
    );

    final platformHighlight = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS =>
        telegram.accent.withValues(alpha: 0.08),
      _ => Colors.transparent,
    };
    final platformSplash = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => NoSplash.splashFactory,
      _ => InkRipple.splashFactory,
    };

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: telegram.chatListBackground,
      canvasColor: telegram.chatBackground,
      dividerColor: telegram.chatListDivider,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      fontFamily: TelegramTypography.platformFontFamily,
      extensions: [telegram],
      splashFactory: platformSplash,
      splashColor: Colors.transparent,
      highlightColor: platformHighlight,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: TelegramSlideTransitionsBuilder(),
          TargetPlatform.iOS: TelegramSlideTransitionsBuilder(),
          TargetPlatform.macOS: TelegramSlideTransitionsBuilder(),
          TargetPlatform.linux: TelegramSlideTransitionsBuilder(),
          TargetPlatform.windows: TelegramSlideTransitionsBuilder(),
          TargetPlatform.fuchsia: TelegramSlideTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: telegram.chatListBackground,
        foregroundColor: telegram.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: IconThemeData(color: telegram.accent),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: telegram.chatListBackground,
        indicatorColor: telegram.accent.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: TelegramFontSizes.time,
            color: selected ? telegram.accent : telegram.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? telegram.accent : telegram.textSecondary,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        color: telegram.bubbleIncoming,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TelegramRadii.bubble),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: telegram.accent,
          foregroundColor: TelegramColors.unreadBadgeText,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TelegramRadii.buttonPill),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: telegram.inputFieldBackground,
        hintStyle: TextStyle(color: telegram.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TelegramRadii.inputField),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TelegramRadii.inputField),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TelegramRadii.inputField),
          borderSide: BorderSide(color: telegram.accent, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      dividerTheme: DividerThemeData(
        color: telegram.chatListDivider,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: telegram.textSecondary,
        textColor: telegram.textPrimary,
        tileColor: telegram.chatListBackground,
        selectedTileColor: telegram.accent.withValues(alpha: 0.08),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TelegramColors.unreadBadgeText;
          }
          return telegram.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return telegram.accent;
          }
          return telegram.textSecondary.withValues(alpha: 0.35);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: telegram.accent,
        foregroundColor: TelegramColors.unreadBadgeText,
        elevation: 2,
        shape: const CircleBorder(),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: telegram.chatListBackground,
        selectedItemColor: telegram.accent,
        unselectedItemColor: telegram.textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: telegram.chatListDivider,
        indicatorColor: telegram.accent,
        labelColor: telegram.accent,
        unselectedLabelColor: telegram.textSecondary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: telegram.elevatedSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TelegramRadii.bubble),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: telegram.elevatedSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TelegramRadii.buttonPill),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: telegram.elevatedSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: telegram.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TelegramRadii.buttonPill),
        ),
      ),
    );
  }

  /// Относительная яркость цвета (WCAG).
  static double relativeLuminance(Color color) {
    double channel(double value) {
      final normalized = value / 255;
      return normalized <= 0.03928
          ? normalized / 12.92
          : math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = channel(color.r * 255);
    final g = channel(color.g * 255);
    final b = channel(color.b * 255);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Контраст двух цветов (WCAG 2.x).
  static double contrastRatio(Color foreground, Color background) {
    final l1 = relativeLuminance(foreground);
    final l2 = relativeLuminance(background);
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Минимальный контраст AA для обычного текста.
  static const double wcagAaNormalText = 4.5;
}

/// Удобный доступ к [TelegramThemeData] из BuildContext.
extension TelegramThemeContext on BuildContext {
  TelegramThemeData get telegramTheme =>
      Theme.of(this).extension<TelegramThemeData>() ??
      TelegramThemeData.light();
}
