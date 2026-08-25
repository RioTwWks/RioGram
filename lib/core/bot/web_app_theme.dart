import 'package:flutter/material.dart';

import '../theme/telegram_theme.dart';

/// Параметры темы TDLib для Mini Apps.
abstract final class WebAppTheme {
  static Map<String, dynamic> themeParameters(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final background = isDark
        ? TelegramColors.appBackgroundDark
        : TelegramColors.chatListBackgroundLight;
    final secondaryBackground = isDark
        ? TelegramColors.elevatedSurfaceDark
        : TelegramColors.chatListDividerLight;
    final headerBackground = isDark
        ? TelegramColors.chatListBackgroundDark
        : TelegramColors.chatListBackgroundLight;
    final sectionBackground = secondaryBackground;
    final textPrimary = isDark
        ? TelegramColors.textPrimaryDark
        : TelegramColors.textPrimaryLight;
    final textSecondary = isDark
        ? TelegramColors.textSecondaryDark
        : TelegramColors.textSecondaryLight;

    return {
      '@type': 'themeParameters',
      'background_color': _toTdlibArgb(background),
      'secondary_background_color': _toTdlibArgb(secondaryBackground),
      'header_background_color': _toTdlibArgb(headerBackground),
      'bottom_bar_background_color': _toTdlibArgb(background),
      'section_background_color': _toTdlibArgb(sectionBackground),
      'section_separator_color': _toTdlibArgb(
        isDark ? const Color(0xFF2B3A4A) : const Color(0xFFE0E0E0),
      ),
      'text_color': _toTdlibArgb(textPrimary),
      'accent_text_color': _toTdlibArgb(TelegramColors.accent),
      'section_header_text_color': _toTdlibArgb(textSecondary),
      'subtitle_text_color': _toTdlibArgb(textSecondary),
      'destructive_text_color': _toTdlibArgb(const Color(0xFFE53935)),
      'hint_color': _toTdlibArgb(textSecondary),
      'link_color': _toTdlibArgb(TelegramColors.accent),
      'button_color': _toTdlibArgb(TelegramColors.accent),
      'button_text_color': _toTdlibArgb(Colors.white),
    };
  }

  static Map<String, String> themeParamsForJs(Brightness brightness) {
    final params = themeParameters(brightness);
    String hex(int argb) {
      final value = argb & 0xFFFFFFFF;
      return '#${value.toRadixString(16).padLeft(8, '0').substring(2)}';
    }

    return {
      'bg_color': hex(params['background_color'] as int),
      'secondary_bg_color': hex(params['secondary_background_color'] as int),
      'header_bg_color': hex(params['header_background_color'] as int),
      'bottom_bar_bg_color': hex(params['bottom_bar_background_color'] as int),
      'section_bg_color': hex(params['section_background_color'] as int),
      'section_separator_color': hex(params['section_separator_color'] as int),
      'text_color': hex(params['text_color'] as int),
      'accent_text_color': hex(params['accent_text_color'] as int),
      'subtitle_text_color': hex(params['subtitle_text_color'] as int),
      'hint_color': hex(params['hint_color'] as int),
      'link_color': hex(params['link_color'] as int),
      'button_color': hex(params['button_color'] as int),
      'button_text_color': hex(params['button_text_color'] as int),
      'destructive_text_color': hex(params['destructive_text_color'] as int),
    };
  }

  static int _toTdlibArgb(Color color) => color.toARGB32();
}
