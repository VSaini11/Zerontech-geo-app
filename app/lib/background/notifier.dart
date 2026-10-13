import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class Notifier {
  static final FlutterLocalNotificationsPlugin _p = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready || kIsWeb) return;
    await _p.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
    );
    await _p
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel('attendance', 'Attendance', description: 'Check-in and check-out alerts', importance: Importance.high));
    _ready = true;
  }

  static Future<void> show(int id, String title, String body) async {
    if (kIsWeb) return;
    try {
      await init();
      await _p.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('attendance', 'Attendance', channelDescription: 'Check-in and check-out alerts', importance: Importance.high, priority: Priority.high),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }
}
