import 'package:flutter/services.dart';

enum NotificationAccess {
  notDetermined,
  authorized,
  provisional,
  denied,
  unavailable
}

/// Permission only. Nitrate does not yet schedule or deliver release alerts.
class NotificationPermission {
  const NotificationPermission();
  static const channel = MethodChannel('nitrate/notification_permission');

  Future<NotificationAccess> status() => _read('status');
  Future<NotificationAccess> request() async {
    final current = await status();
    if (current != NotificationAccess.notDetermined) return current;
    return _read('request');
  }

  Future<NotificationAccess> _read(String method) async {
    final value = await channel.invokeMethod<String>(method);
    return NotificationAccess.values.firstWhere((s) => s.name == value,
        orElse: () => NotificationAccess.unavailable);
  }

  Future<void> openSettings() async {
    if (await channel.invokeMethod<bool>('openSettings') != true) {
      throw StateError('Notification settings unavailable');
    }
  }
}
