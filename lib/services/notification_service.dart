import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize notifications
  static Future<void> initialize() async {
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

  // Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Foreground message: ${message.messageId}');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');
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

    switch (type) {
      case 'food_claimed':
        // Navigate to post details or my posts
        break;
      case 'claim_accepted':
      case 'claim_rejected':
        // Navigate to my claims
        break;
      case 'new_food_nearby':
        // Navigate to food listings or map
        break;
      case 'new_message':
        // Navigate to chat
        break;
      default:
        // Navigate to home
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
