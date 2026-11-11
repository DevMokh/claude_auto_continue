import 'native_channel.dart';

/// Notifications are posted natively (no extra Flutter plugin to break).
class NotificationService {
  NotificationService(this._native);

  final NativeChannel _native;

  Future<void> updateOngoing(String title, String text) =>
      _native.updateNotification(title, text);

  Future<void> alert(String title, String text) =>
      _native.notifyAttention(title, text);

  Future<bool> hasPermission() => _native.hasNotificationPermission();

  Future<bool> requestPermission() => _native.requestNotificationPermission();
}
