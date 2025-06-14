import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  late final SharedPreferences _prefs;
  final MethodChannel _channel = const MethodChannel(
    'com.example.zerowaste_app/notifications',
  );
  bool _isInitialized = false;

  // Notification settings keys
  static const String _foodClaimedKey = 'notify_food_claimed';
  static const String _newMessageKey = 'notify_new_message';
  static const String _nearbyPostKey = 'notify_nearby_post';

  NotificationService._internal();

  Future<void> initialize(SharedPreferences prefs) async {
    if (_isInitialized) {
      debugPrint('NotificationService already initialized');
      return;
    }

    try {
      _prefs = prefs;

      // Set default values if they don't exist
      if (!_prefs.containsKey(_foodClaimedKey)) {
        await _prefs.setBool(_foodClaimedKey, true);
      }
      if (!_prefs.containsKey(_newMessageKey)) {
        await _prefs.setBool(_newMessageKey, true);
      }
      if (!_prefs.containsKey(_nearbyPostKey)) {
        await _prefs.setBool(_nearbyPostKey, true);
      }

      // Initialize platform channel
      await _channel.invokeMethod('initialize');
      _isInitialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize notifications: $e');
      // Don't throw the error, just log it and continue
      _isInitialized = false;
    }
  }

  // Notification settings getters with null safety
  bool get notifyFoodClaimed {
    if (!_isInitialized) {
      debugPrint(
        'NotificationService not initialized, returning default value for food claimed',
      );
      return true;
    }
    return _prefs.getBool(_foodClaimedKey) ?? true;
  }

  bool get notifyNewMessage {
    if (!_isInitialized) {
      debugPrint(
        'NotificationService not initialized, returning default value for new message',
      );
      return true;
    }
    return _prefs.getBool(_newMessageKey) ?? true;
  }

  bool get notifyNearbyPost {
    if (!_isInitialized) {
      debugPrint(
        'NotificationService not initialized, returning default value for nearby post',
      );
      return true;
    }
    return _prefs.getBool(_nearbyPostKey) ?? true;
  }

  // Notification settings setters with error handling
  Future<void> setNotifyFoodClaimed(bool value) async {
    if (!_isInitialized) {
      debugPrint(
        'NotificationService not initialized, cannot set food claimed notification',
      );
      return;
    }
    try {
      await _prefs.setBool(_foodClaimedKey, value);
      debugPrint('Food claimed notification setting updated: $value');
    } catch (e) {
      debugPrint('Failed to set food claimed notification: $e');
    }
  }

  Future<void> setNotifyNewMessage(bool value) async {
    if (!_isInitialized) {
      debugPrint(
        'NotificationService not initialized, cannot set new message notification',
      );
      return;
    }
    try {
      await _prefs.setBool(_newMessageKey, value);
      debugPrint('New message notification setting updated: $value');
    } catch (e) {
      debugPrint('Failed to set new message notification: $e');
    }
  }

  Future<void> setNotifyNearbyPost(bool value) async {
    if (!_isInitialized) {
      debugPrint(
        'NotificationService not initialized, cannot set nearby post notification',
      );
      return;
    }
    try {
      await _prefs.setBool(_nearbyPostKey, value);
      debugPrint('Nearby post notification setting updated: $value');
    } catch (e) {
      debugPrint('Failed to set nearby post notification: $e');
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      debugPrint(
        'NotificationService not initialized, skipping notification: $title',
      );
      return;
    }

    try {
      await _channel.invokeMethod('showNotification', {
        'title': title,
        'body': body,
        'payload': payload,
      });
      debugPrint('Notification shown successfully: $title');
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  Future<void> showFoodExpiryNotification({
    required String foodName,
    required DateTime expiryDate,
  }) async {
    if (!_isInitialized || !notifyFoodClaimed) {
      debugPrint(
        'Skipping food expiry notification: Service not initialized or notifications disabled',
      );
      return;
    }

    try {
      final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
      final title = 'Food Expiring Soon';
      final body = '$foodName will expire in $daysUntilExpiry days';

      await showNotification(title: title, body: body, payload: 'food_expiry');
    } catch (e) {
      debugPrint('Failed to show food expiry notification: $e');
    }
  }

  Future<void> showDonationNotification({
    required String foodName,
    required String location,
  }) async {
    if (!_isInitialized || !notifyNearbyPost) {
      debugPrint(
        'Skipping donation notification: Service not initialized or notifications disabled',
      );
      return;
    }

    try {
      final title = 'New Food Donation';
      final body = '$foodName is available near $location';

      await showNotification(title: title, body: body, payload: 'new_donation');
    } catch (e) {
      debugPrint('Failed to show donation notification: $e');
    }
  }

  Future<void> showMessageNotification({
    required String senderName,
    required String message,
  }) async {
    if (!_isInitialized || !notifyNewMessage) {
      debugPrint(
        'Skipping message notification: Service not initialized or notifications disabled',
      );
      return;
    }

    try {
      final title = 'New Message from $senderName';
      final body = message;

      await showNotification(title: title, body: body, payload: 'new_message');
    } catch (e) {
      debugPrint('Failed to show message notification: $e');
    }
  }
}
