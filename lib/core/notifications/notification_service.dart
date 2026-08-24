import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Локальные уведомления о новых сообщениях.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: LinuxInitializationSettings(defaultActionName: 'Открыть'),
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> showMessageNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await init();
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'riogram_messages',
        'Сообщения',
        channelDescription: 'Уведомления о новых сообщениях RioGram',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
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
