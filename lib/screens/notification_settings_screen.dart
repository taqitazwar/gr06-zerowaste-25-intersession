import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationService = Provider.of<NotificationService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Food Claimed Notifications'),
            subtitle: const Text(
              'Get notified when someone claims your posted food',
            ),
            value: notificationService.notifyFoodClaimed,
            onChanged: (bool value) {
              notificationService.setNotifyFoodClaimed(value);
            },
          ),
          SwitchListTile(
            title: const Text('New Message Notifications'),
            subtitle: const Text('Get notified when you receive a new message'),
            value: notificationService.notifyNewMessage,
            onChanged: (bool value) {
              notificationService.setNotifyNewMessage(value);
            },
          ),
          SwitchListTile(
            title: const Text('Nearby Post Notifications'),
            subtitle: const Text('Get notified when new food is posted nearby'),
            value: notificationService.notifyNearbyPost,
            onChanged: (bool value) {
              notificationService.setNotifyNearbyPost(value);
            },
          ),
        ],
      ),
    );
  }
}
