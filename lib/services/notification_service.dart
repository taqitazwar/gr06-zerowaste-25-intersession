import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final SharedPreferences _prefs;

  // Notification settings keys
  static const String _foodClaimedKey = 'notify_food_claimed';
  static const String _newMessageKey = 'notify_new_message';
  static const String _nearbyPostKey = 'notify_nearby_post';

  NotificationService(this._prefs) {
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    // Request permission for iOS
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(initializationSettings);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }

  // Notification settings getters and setters
  bool get notifyFoodClaimed => _prefs.getBool(_foodClaimedKey) ?? true;
  bool get notifyNewMessage => _prefs.getBool(_newMessageKey) ?? true;
  bool get notifyNearbyPost => _prefs.getBool(_nearbyPostKey) ?? true;

  Future<void> setNotifyFoodClaimed(bool value) async {
    await _prefs.setBool(_foodClaimedKey, value);
  }

  Future<void> setNotifyNewMessage(bool value) async {
    await _prefs.setBool(_newMessageKey, value);
  }

  Future<void> setNotifyNearbyPost(bool value) async {
    await _prefs.setBool(_nearbyPostKey, value);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (!_shouldShowNotification(message.data['type'])) return;

    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Handle notification tap based on the message type
    final type = message.data['type'];
    final id = message.data['id'];

    switch (type) {
      case 'food_claimed':
        // Navigate to food post details
        break;
      case 'new_message':
        // Navigate to chat
        break;
      case 'nearby_post':
        // Navigate to nearby posts
        break;
    }
  }

  bool _shouldShowNotification(String? type) {
    switch (type) {
      case 'food_claimed':
        return notifyFoodClaimed;
      case 'new_message':
        return notifyNewMessage;
      case 'nearby_post':
        return notifyNearbyPost;
      default:
        return true;
    }
  }
}

// This needs to be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages here
  print('Handling a background message: ${message.messageId}');
}
