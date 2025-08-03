import 'dart:html' as html;

class WebNotificationService {
  static bool _permissionRequested = false;
  static String _permissionStatus = 'default';

  static Future<void> initializeWebNotifications() async {
    try {
      if (!_permissionRequested) {
        _permissionRequested = true;

        // Check if notifications are supported
        if (html.Notification.supported) {
          // Request permission
          final permission = await html.Notification.requestPermission();
          _permissionStatus = permission;
          print('Web notifications initialized with permission: $permission');

          if (permission == 'granted') {
            // Show a test notification to confirm it's working
            html.Notification(
              'AProfileo Chat',
              body: 'Notifications enabled successfully!',
              icon: '/favicon.png',
            );
          } else {
            print('Notification permission denied or not granted');
          }
        } else {
          print('Notifications not supported in this browser');
        }
      }
    } catch (e) {
      print('Error initializing web notifications: $e');
    }
  }

  static Future<void> showWebNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    try {
      if (html.Notification.supported) {
        if (_permissionStatus == 'granted') {
          // Show actual browser notification
          final notification = html.Notification(
            title,
            body: body,
            icon: '/favicon.png',
            tag: payload ?? 'chat-notification',
          );

          // Auto-close after 5 seconds
          Future.delayed(const Duration(seconds: 5), () {
            notification.close();
          });

          print('Web Notification shown: $title - $body');
        } else {
          print('Cannot show notification - permission not granted');
        }
      } else {
        // Fallback for unsupported browsers
        print('Web Notification: $title - $body');
      }
    } catch (e) {
      print('Error showing web notification: $e');
    }
  }

  static bool get canShowNotifications {
    return html.Notification.supported && _permissionStatus == 'granted';
  }

  static String get permissionStatus => _permissionStatus;
}
