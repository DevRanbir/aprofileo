import 'package:flutter/foundation.dart';
import 'notification_service_web.dart'
    if (dart.library.io) 'notification_service_stub.dart';
import 'notification_service_mobile.dart';

class NotificationService {
  Future<void> initialize() async {
    if (kIsWeb) {
      // Web notification initialization
      await WebNotificationService.initializeWebNotifications();
    } else {
      // Mobile notification initialization
      await MobileNotificationService.initializeMobileNotifications();
    }
  }

  Future<void> showNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    if (kIsWeb) {
      await WebNotificationService.showWebNotification(
        title,
        body,
        payload: payload,
      );
    } else {
      await MobileNotificationService.showMobileNotification(
        title,
        body,
        payload: payload,
      );
    }
  }

  Future<void> cancelAll() async {
    if (!kIsWeb) {
      await MobileNotificationService.cancelAll();
    }
  }

  // Subscribe to topic for receiving push notifications (mobile only)
  Future<void> subscribeToTopic(String topic) async {
    if (!kIsWeb) {
      await MobileNotificationService.subscribeToTopic(topic);
    }
  }

  // Unsubscribe from topic (mobile only)
  Future<void> unsubscribeFromTopic(String topic) async {
    if (!kIsWeb) {
      await MobileNotificationService.unsubscribeFromTopic(topic);
    }
  }

  // Get FCM token for targeted notifications (mobile only)
  String? get fcmToken {
    if (!kIsWeb) {
      return MobileNotificationService.fcmToken;
    }
    return null;
  }

  // Refresh FCM token (mobile only)
  Future<String?> refreshToken() async {
    if (!kIsWeb) {
      return await MobileNotificationService.refreshToken();
    }
    return null;
  }

  // Simple in-app notification for both platforms
  static void showInAppNotification(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    print('In-App Notification: $title - $message');
    // This could be enhanced with a custom overlay widget
  }

  // Check if notifications are available and permission is granted
  bool get canShowNotifications {
    if (kIsWeb) {
      return WebNotificationService.canShowNotifications;
    }
    return true; // Assume mobile notifications work if initialized
  }

  // Get current permission status
  String get permissionStatus {
    if (kIsWeb) {
      return WebNotificationService.permissionStatus;
    }
    return 'granted'; // Assume granted for mobile
  }

  // Debug methods for mobile
  Future<void> debugNotificationStatus() async {
    if (!kIsWeb) {
      await MobileNotificationService.debugNotificationStatus();
    }
  }

  Future<void> sendTestNotification() async {
    if (!kIsWeb) {
      await MobileNotificationService.sendTestNotification();
    }
  }

  Future<void> sendQuickTestNotification() async {
    if (!kIsWeb) {
      await MobileNotificationService.sendQuickTestNotification();
    }
  }
}
