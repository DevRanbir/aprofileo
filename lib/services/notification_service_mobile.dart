import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class MobileNotificationService {
  static FirebaseMessaging? _messaging;
  static String? _fcmToken;
  static FlutterLocalNotificationsPlugin? _localNotifications;

  static Future<void> initializeMobileNotifications() async {
    try {
      // Initialize Local Notifications
      _localNotifications = FlutterLocalNotificationsPlugin();

      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
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

      await _localNotifications!.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android
      await _createNotificationChannel();

      // Initialize Firebase Messaging
      _messaging = FirebaseMessaging.instance;

      // Request permission for notifications
      NotificationSettings settings = await _messaging!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');

        // Get the FCM token
        _fcmToken = await _messaging!.getToken();
        print('FCM Token: $_fcmToken');

        // Configure foreground message handler
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Configure background message handler
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );

        // Handle notification taps when app is terminated
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        // Check if app was opened from a terminated state
        RemoteMessage? initialMessage = await _messaging!.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        print('User granted provisional permission');
      } else {
        print('User declined or has not accepted permission');
      }
    } catch (e) {
      print('Error initializing mobile notifications: $e');
    }
  }

  // Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    print('=== FOREGROUND MESSAGE RECEIVED ===');
    print('Message ID: ${message.messageId}');
    print('Data: ${message.data}');

    if (message.notification != null) {
      print(
        'Firebase Notification: ${message.notification!.title} - ${message.notification!.body}',
      );

      // Show local notification even for foreground messages
      _showLocalNotification(
        message.notification!.title ?? 'New Message',
        message.notification!.body ?? '',
        payload: message.data['threadId'] ?? '',
      );
    } else if (message.data.isNotEmpty) {
      // Handle data-only messages
      final title = message.data['title'] ?? 'New Message';
      final body = message.data['body'] ?? 'You have a new message';

      _showLocalNotification(
        title,
        body,
        payload: message.data['threadId'] ?? '',
      );
    }
    print('===================================');
  }

  // Handle when user taps on notification
  static void _handleMessageOpenedApp(RemoteMessage message) {
    print('A new onMessageOpenedApp event was published!');
    print('Message data: ${message.data}');
    // Navigate to specific screen based on message data
    // You can add navigation logic here
  }

  // Handle local notification taps
  static void _onNotificationTapped(NotificationResponse notificationResponse) {
    print('Local notification tapped!');
    print('Payload: ${notificationResponse.payload}');
    // Handle navigation based on payload
  }

  // Create notification channel for Android
  static Future<void> _createNotificationChannel() async {
    if (_localNotifications != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'chat_channel', // Channel ID
        'Chat Notifications', // Channel name
        description: 'Notifications for chat messages',
        importance: Importance.max,
      );

      await _localNotifications!
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }
  }

  static Future<void> showMobileNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    try {
      // For mobile, we typically send notifications via server
      // This method could be used to send to FCM server or show local notifications
      await _showLocalNotification(title, body, payload: payload);
    } catch (e) {
      print('Error showing mobile notification: $e');
    }
  }

  // Show local notification
  static Future<void> _showLocalNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    try {
      print('=== NOTIFICATION RECEIVED ===');
      print('Title: $title');
      print('Body: $body');
      print('Payload: $payload');
      print('=============================');

      if (_localNotifications != null) {
        // Create notification details
        const AndroidNotificationDetails androidNotificationDetails =
            AndroidNotificationDetails(
              'chat_channel', // Channel ID
              'Chat Notifications', // Channel name
              channelDescription: 'Notifications for chat messages',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
              icon: '@mipmap/ic_launcher',
              color: Color(0xFFbe00ff),
              enableVibration: true,
              playSound: true,
            );

        const DarwinNotificationDetails iosNotificationDetails =
            DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            );

        const NotificationDetails notificationDetails = NotificationDetails(
          android: androidNotificationDetails,
          iOS: iosNotificationDetails,
        );

        // Show the notification
        await _localNotifications!.show(
          DateTime.now().millisecondsSinceEpoch.remainder(100000), // Unique ID
          title,
          body,
          notificationDetails,
          payload: payload,
        );

        print('✅ Local notification displayed successfully!');
      } else {
        print('❌ Local notifications not initialized');
      }
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  static Future<void> cancelAll() async {
    try {
      // Cancel all local notifications
      if (_localNotifications != null) {
        await _localNotifications!.cancelAll();
        print('All local notifications cancelled');
      }
    } catch (e) {
      print('Error canceling notifications: $e');
    }
  }

  // Subscribe to topic for receiving notifications
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging?.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  // Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging?.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }

  // Get FCM token for sending targeted notifications
  static String? get fcmToken => _fcmToken;

  // Check if the service is initialized
  static bool get isInitialized => _messaging != null;

  // Debug method to check notification status
  static Future<void> debugNotificationStatus() async {
    print('=== NOTIFICATION DEBUG INFO ===');
    print('Messaging initialized: ${_messaging != null}');
    print('FCM Token: $_fcmToken');

    if (_messaging != null) {
      try {
        NotificationSettings settings = await _messaging!
            .getNotificationSettings();
        print('Authorization Status: ${settings.authorizationStatus}');
        print('Alert Setting: ${settings.alert}');
        print('Badge Setting: ${settings.badge}');
        print('Sound Setting: ${settings.sound}');
      } catch (e) {
        print('Error getting notification settings: $e');
      }
    }
    print('==============================');
  }

  // Test method to send a test notification
  static Future<void> sendTestNotification() async {
    print('Sending test notification...');
    await showMobileNotification(
      'Test Notification',
      'This is a test notification to check if everything is working!',
      payload: 'test_payload',
    );
  }

  // Quick test method for immediate notification
  static Future<void> sendQuickTestNotification() async {
    try {
      if (_localNotifications != null) {
        const AndroidNotificationDetails androidDetails =
            AndroidNotificationDetails(
              'chat_channel',
              'Chat Notifications',
              channelDescription: 'Notifications for chat messages',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
              icon: '@mipmap/ic_launcher',
              color: Color(0xFFbe00ff),
            );

        const NotificationDetails notificationDetails = NotificationDetails(
          android: androidDetails,
        );

        await _localNotifications!.show(
          999, // Fixed ID for test
          '🔔 Quick Test',
          'If you see this, notifications are working perfectly!',
          notificationDetails,
          payload: 'quick_test',
        );

        print('✅ Quick test notification sent!');
      } else {
        print('❌ Local notifications not initialized');
      }
    } catch (e) {
      print('❌ Error sending quick test notification: $e');
    }
  }

  // Refresh FCM token
  static Future<String?> refreshToken() async {
    try {
      if (_messaging == null) {
        print('Error: Firebase Messaging not initialized');
        return null;
      }
      _fcmToken = await _messaging?.getToken();
      print('Refreshed FCM Token: $_fcmToken');
      return _fcmToken;
    } catch (e) {
      print('Error refreshing FCM token: $e');
      return null;
    }
  }
}

// This must be a top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('=== BACKGROUND MESSAGE RECEIVED ===');
  print('Message ID: ${message.messageId}');
  print('From: ${message.from}');
  print('Data: ${message.data}');
  if (message.notification != null) {
    print('Notification Title: ${message.notification!.title}');
    print('Notification Body: ${message.notification!.body}');
  }
  print('===================================');

  try {
    // Initialize Firebase for background processing
    await Firebase.initializeApp();
    
    // Initialize local notifications for background processing
    final FlutterLocalNotificationsPlugin localNotifications =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await localNotifications.initialize(initializationSettings);

    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'chat_channel',
      'Chat Notifications',
      description: 'Notifications for chat messages',
      importance: Importance.max,
    );

    await localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    String title = 'New Message';
    String body = 'You have a new message';
    String payload = '';

    // Determine notification content
    if (message.notification != null) {
      title = message.notification!.title ?? 'New Message';
      body = message.notification!.body ?? 'You have a new message';
      payload = message.data['threadId'] ?? message.data['payload'] ?? '';
    } else if (message.data.isNotEmpty) {
      title = message.data['title'] ?? 'New Message';
      body = message.data['body'] ?? 'You have a new message';
      payload = message.data['threadId'] ?? message.data['payload'] ?? '';
    }

    // Show notification
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'chat_channel',
          'Chat Notifications',
          channelDescription: 'Notifications for chat messages',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFbe00ff),
          enableVibration: true,
          playSound: true,
          autoCancel: true,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    await localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    print('✅ Background notification displayed successfully!');
  } catch (e) {
    print('❌ Error in background message handler: $e');
  }
}
