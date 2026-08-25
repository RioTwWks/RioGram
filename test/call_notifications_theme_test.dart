import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/notifications/notification_service.dart';
import 'package:riogram/core/theme/telegram_theme.dart';

void main() {
  group('§9.8 call theme tokens', () {
    test('call background is pure black', () {
      expect(TelegramColors.callBackground, const Color(0xFF000000));
    });

    test('accept and decline button colors', () {
      expect(TelegramColors.callAcceptGreen, const Color(0xFF4CB050));
      expect(TelegramColors.callDeclineRed, const Color(0xFFE53935));
    });

    test('call control sizes match Telegram-like layout', () {
      expect(TelegramSpacing.callAvatarRadius, 60);
      expect(TelegramSpacing.callPrimaryButtonSize, 72);
      expect(TelegramSpacing.callControlButtonSize, 64);
    });
  });

  group('NotificationService §9.8', () {
    test('uses system-style channel without custom layout id', () {
      expect(NotificationService.messagesChannelId, 'riogram_messages');
      expect(NotificationService.messagesChannelName, 'Сообщения');
    });
  });
}
