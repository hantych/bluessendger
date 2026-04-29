import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> showMessage({
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'ghost_mesh_messages',
      'Messages',
      channelDescription: 'Incoming messages from nearby peers',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      chatId.hashCode,
      senderName,
      message,
      details,
      payload: chatId,
    );
  }
}
