// Stub implementation for non-web platforms
class WebNotificationService {
  static Future<void> initializeWebNotifications() async {
    // No-op for non-web platforms
  }

  static Future<void> showWebNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    // No-op for non-web platforms
    print('Web notifications not available on this platform');
  }

  static bool get canShowNotifications => false;

  static String get permissionStatus => 'denied';
}
