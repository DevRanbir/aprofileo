import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';

class BackgroundNotificationService {
  static BackgroundNotificationService? _instance;
  static BackgroundNotificationService get instance {
    _instance ??= BackgroundNotificationService._internal();
    return _instance!;
  }

  BackgroundNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  StreamSubscription? _notificationRequestSubscription;
  bool _isMonitoring = false;

  /// Start monitoring for admin notification requests
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    try {
      await _notificationService.initialize();

      // Subscribe to FCM topic for immediate notifications
      await FirebaseMessaging.instance.subscribeToTopic('admin_notifications');

      // Monitor Firestore for notification requests (backup for when app is backgrounded)
      _notificationRequestSubscription = _firestore
          .collection('admin_notification_requests')
          .where('processed', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots()
          .listen(_processNotificationRequests);

      _isMonitoring = true;
      print('🔔 Background notification monitoring started');
      print('🔔 Subscribed to admin_notifications topic');
    } catch (e) {
      print('❌ Error starting background notification monitoring: $e');
    }
  }

  /// Process notification requests from Firestore
  void _processNotificationRequests(QuerySnapshot snapshot) {
    for (final doc in snapshot.docChanges) {
      if (doc.type == DocumentChangeType.added) {
        _processNotificationRequest(doc.doc);
      }
    }
  }

  /// Process a single notification request
  Future<void> _processNotificationRequest(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;

      // Check if already processed
      if (data['processed'] == true || data['notificationSent'] == true) {
        return;
      }

      final userName = data['userName'] ?? 'Unknown User';
      final messageContent = data['messageContent'] ?? '';
      final title = 'New message from $userName';
      final body = messageContent.length > 50
          ? '${messageContent.substring(0, 50)}...'
          : messageContent;

      // Show local notification
      await _notificationService.showNotification(
        title,
        body,
        payload: 'admin_chat_${data['userId']}',
      );

      // Mark as processed
      await doc.reference.update({
        'processed': true,
        'notificationSent': true,
        'processedAt': FieldValue.serverTimestamp(),
      });

      print('🔔 Background notification sent: $title');
    } catch (e) {
      print('❌ Error processing notification request: $e');
    }
  }

  /// Stop monitoring
  void stopMonitoring() {
    _notificationRequestSubscription?.cancel();
    _notificationRequestSubscription = null;
    _isMonitoring = false;
    print('🔔 Background notification monitoring stopped');
  }

  /// Check if monitoring is active
  bool get isMonitoring => _isMonitoring;
}
