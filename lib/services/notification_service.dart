import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Global navigator key to access context from anywhere
  static GlobalKey<NavigatorState>? navigatorKey;

  // Initialize notifications
  static Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    navigatorKey = navKey;
    
    // Initialize local notifications
    await _initializeLocalNotifications();
    
    // Request permission for iOS
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('Notification permission status: ${settings.authorizationStatus}');

    // Handle token refresh
    _messaging.onTokenRefresh.listen(_handleTokenRefresh);

    // Get initial token and update if permissions are granted
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _updateFCMToken();
    }

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    
    // Handle notification taps when app is terminated
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationTap(message);
      }
    });
  }

  // Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'zerowaste_channel',
      'ZeroWaste Notifications',
      description: 'Notifications for food sharing activities',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Handle local notification tap
  static void _onLocalNotificationTap(NotificationResponse response) {
    print('Local notification tapped: ${response.payload}');
    if (response.payload != null) {
      // Parse the payload and navigate accordingly
      // You can store notification data as JSON in the payload
    }
  }

  // Handle token refresh
  static Future<void> _handleTokenRefresh(String token) async {
    print('FCM Token refreshed: $token');
    await _updateFCMTokenWithValue(token);
  }

  // Update FCM token for current user
  static Future<void> _updateFCMToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token != null) {
        await _updateFCMTokenWithValue(token);
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  // Update FCM token with specific value
  static Future<void> _updateFCMTokenWithValue(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'lastActive': Timestamp.fromDate(DateTime.now()),
      });
      print('FCM token updated for user: ${user.uid}');
    } catch (e) {
      print('Error updating FCM token in Firestore: $e');
    }
  }

  // Request notification permissions (can be called anytime)
  static Future<bool> requestPermissions() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      bool isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (isAuthorized) {
        // Update token when permissions are granted
        await _updateFCMToken();
      }

      return isAuthorized;
    } catch (e) {
      print('Error requesting notification permissions: $e');
      return false;
    }
  }

  // Check current permission status
  static Future<AuthorizationStatus> getPermissionStatus() async {
    try {
      NotificationSettings settings = await _messaging
          .getNotificationSettings();
      return settings.authorizationStatus;
    } catch (e) {
      print('Error getting permission status: $e');
      return AuthorizationStatus.notDetermined;
    }
  }

  // Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Background message: ${message.messageId}');
  }

  // Handle foreground messages - THIS IS THE KEY FIX!
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Foreground message: ${message.messageId}');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');

    // Show local notification when app is in foreground
    await _showLocalNotification(message);
    
    // Optionally show in-app notification banner
    _showInAppNotification(message);
  }

  // Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Get notification icon based on type
    String icon = '@mipmap/ic_launcher';
    String channelId = 'zerowaste_channel';
    
    final notificationType = message.data['type'] ?? '';
    switch (notificationType) {
      case 'food_claimed':
        icon = '@drawable/ic_food_claimed';
        break;
      case 'claim_accepted':
        icon = '@drawable/ic_claim_accepted';
        break;
      case 'new_food_nearby':
        icon = '@drawable/ic_food_nearby';
        break;
      case 'new_message':
        icon = '@drawable/ic_message';
        break;
      case 'new_rating':
        icon = '@drawable/ic_rating';
        break;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'zerowaste_channel',
      'ZeroWaste Notifications',
      channelDescription: 'Notifications for food sharing activities',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      platformChannelSpecifics,
      payload: message.data.toString(), // Store data for handling taps
    );
  }

  // Show in-app notification banner
  static void _showInAppNotification(RemoteMessage message) {
    final context = navigatorKey?.currentContext;
    if (context == null) return;

    final notification = message.notification;
    if (notification == null) return;

    // Show a snackbar or custom banner
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title ?? 'Notification',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (notification.body != null)
              Text(
                notification.body!,
                style: const TextStyle(color: Colors.white),
              ),
          ],
        ),
        backgroundColor: _getNotificationColor(message.data['type']),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () => _handleNotificationTap(message),
        ),
      ),
    );
  }

  // Get notification color based on type
  static Color _getNotificationColor(String? type) {
    switch (type) {
      case 'food_claimed':
        return Colors.blue;
      case 'claim_accepted':
        return Colors.green;
      case 'claim_rejected':
        return Colors.orange;
      case 'new_food_nearby':
        return Colors.purple;
      case 'new_message':
        return Colors.indigo;
      case 'new_rating':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  // Handle notification tap
  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    print('Notification tapped: ${message.messageId}');
    // Navigate to appropriate screen based on notification data
    _navigateBasedOnNotification(message);
  }

  // Navigate based on notification type
  static void _navigateBasedOnNotification(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    final context = navigatorKey?.currentContext;
    
    if (context == null) return;

    switch (type) {
      case 'food_claimed':
        // Navigate to post details or my posts
        Navigator.pushNamed(context, '/my-posts');
        break;
      case 'claim_accepted':
      case 'claim_rejected':
        // Navigate to my claims
        Navigator.pushNamed(context, '/my-claims');
        break;
      case 'new_food_nearby':
        // Navigate to food listings or map
        Navigator.pushNamed(context, '/food-listings');
        break;
      case 'new_message':
        // Navigate to chat
        final chatId = data['chatId'];
        if (chatId != null) {
          Navigator.pushNamed(context, '/chat', arguments: {'chatId': chatId});
        }
        break;
      case 'new_rating':
        // Navigate to profile
        Navigator.pushNamed(context, '/profile');
        break;
      default:
        // Navigate to home
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        break;
    }
  }

  // Get FCM token
  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  // Manually refresh and update token (useful for settings screen)
  static Future<void> refreshToken() async {
    await _updateFCMToken();
  }
}
