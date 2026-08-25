import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Локальные уведомления о новых сообщениях и badge на иконке.
///
/// §9.8: системный стиль ОС (иконка приложения, без кастомных glass/banner layout).
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String messagesChannelId = 'riogram_messages';
  static const String messagesChannelName = 'Сообщения';
  static const String messagesChannelDescription =
      'Уведомления о новых сообщениях RioGram';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  int _badgeCount = 0;

  int get badgeCount => _badgeCount;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestBadgePermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: LinuxInitializationSettings(defaultActionName: 'Открыть'),
    );

    await _plugin.initialize(settings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          messagesChannelId,
          messagesChannelName,
          description: messagesChannelDescription,
          importance: Importance.high,
        ),
      );
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final macos = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    await macos?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> updateBadgeCount(int count) async {
    if (!_initialized) {
      await init();
    }
    _badgeCount = count.clamp(0, 99999);

    try {
      await _plugin.show(
        0,
        null,
        null,
        NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentSound: false,
            presentBanner: false,
            badgeNumber: _badgeCount,
          ),
          macOS: DarwinNotificationDetails(
            presentAlert: false,
            presentSound: false,
            badgeNumber: _badgeCount,
          ),
        ),
      );
      if (_badgeCount == 0) {
        await _plugin.cancel(0);
      }
    } catch (error) {
      debugPrint('NotificationService: badge update failed: $error');
    }
  }

  Future<void> showMessageNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await init();
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        messagesChannelId,
        messagesChannelName,
        channelDescription: messagesChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        styleInformation: const DefaultStyleInformation(false, false),
        visibility: NotificationVisibility.public,
        number: _badgeCount > 0 ? _badgeCount : null,
        channelShowBadge: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBanner: true,
        badgeNumber: _badgeCount > 0 ? _badgeCount : null,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        badgeNumber: _badgeCount > 0 ? _badgeCount : null,
      ),
      linux: const LinuxNotificationDetails(),
    );

    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        details,
      );
    } catch (error) {
      debugPrint('NotificationService: show failed: $error');
    }
  }
}
