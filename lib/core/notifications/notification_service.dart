import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Локальные уведомления о новых сообщениях и badge на иконке.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

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
        'riogram_messages',
        'Сообщения',
        channelDescription: 'Уведомления о новых сообщениях RioGram',
        importance: Importance.high,
        priority: Priority.high,
        number: _badgeCount > 0 ? _badgeCount : null,
      ),
      iOS: DarwinNotificationDetails(
        badgeNumber: _badgeCount > 0 ? _badgeCount : null,
      ),
      macOS: DarwinNotificationDetails(
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
      // Linux: ExcessNotificationGeneration при лавине однотипных notify.
      debugPrint('NotificationService: show failed: $error');
    }
  }
}
