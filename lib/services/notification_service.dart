import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/chat_models.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // Create multiple notification instances for redundancy
  for (int i = 0; i < 3; i++) {
    try {
      final notificationService = NotificationService._backgroundInstance();
      await notificationService._initializeLocalNotifications();
      await notificationService._createNotificationChannel();
      await notificationService._showFirebaseNotification(message);

      // Also create direct local notifications
      await notificationService._flutterLocalNotificationsPlugin.show(
        (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch) +
            i,
        message.notification?.title ?? 'New Message',
        message.notification?.body ?? 'You have a new message',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'chat_channel',
            'Chat Messages',
            channelDescription: 'Notifications for new chat messages',
            importance: Importance.max,
            priority: Priority.max,
            autoCancel: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.message,
            playSound: true,
            enableVibration: true,
            ongoing: false,
          ),
        ),
      );

      // Break if successful
      break;
    } catch (e) {
      // Continue to next attempt
      if (i == 2) {
        // Last attempt - create emergency notification
        try {
          final emergencyService = NotificationService._backgroundInstance();
          await emergencyService._initializeLocalNotifications();
          await emergencyService._flutterLocalNotificationsPlugin.show(
            999999,
            'Message Received',
            'You have a new message',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'emergency_channel',
                'Emergency Notifications',
                importance: Importance.max,
                priority: Priority.max,
              ),
            ),
          );
        } catch (emergencyError) {
          // Final fallback - do nothing
        }
      }
    }
  }
}

class NotificationService with WidgetsBindingObserver {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Background instance constructor for isolated use
  NotificationService._backgroundInstance();

  // Flutter Local Notifications
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Firebase Messaging
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  // Background notification processing timers - multiple redundant timers
  Timer? _primaryNotificationTimer;
  Timer? _secondaryNotificationTimer;
  Timer? _emergencyNotificationTimer;

  // Application state
  bool _isInBackground = false;
  bool _isOfflineMode = false;

  // Multiple backup systems for message tracking
  DateTime? _lastProcessedTimestamp;
  final Set<String> _processedMessageIds = <String>{};
  final Map<String, DateTime> _messageProcessingHistory = {};
  final List<Map<String, dynamic>> _pendingNotificationQueue = [];

  // Notification grouping system
  final Map<String, List<ChatMessage>> _pendingNotificationsByUser = {};
  final Map<String, Timer> _notificationTimers = {};
  static const Duration _notificationGroupingDelay = Duration(seconds: 3);

  // Current user ID to filter out own messages
  String? _currentUserId;

  // Notification channels
  static const String _chatChannelId = 'chat_channel';
  static const String _chatChannelName = 'Chat Messages';
  static const String _chatChannelDescription =
      'Notifications for new chat messages';

  // Flag to track initialization
  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (Platform.isAndroid && !_isInitialized) {
      await _enableOfflinePersistence();
      await _initializeLocalNotifications();
      await _initializeFirebaseMessaging();
      await _setupFirestoreListener();
      _startNotificationProcessingTimer();

      // Start persistent background monitoring
      _startPersistentBackgroundMonitoring();

      // Add lifecycle observer
      WidgetsBinding.instance.addObserver(this);

      _isInitialized = true;
    }
  }

  /// Start persistent background monitoring that works even when app is killed
  void _startPersistentBackgroundMonitoring() {
    // Multiple timers for redundancy
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _createPersistentNotificationCheck();
    });

    Timer.periodic(const Duration(minutes: 1), (timer) async {
      await _createHeartbeatNotification();
    });
  }

  /// Create persistent notification check
  Future<void> _createPersistentNotificationCheck() async {
    try {
      await _firestore.collection('persistent_checks').add({
        'type': 'background_active',
        'timestamp': FieldValue.serverTimestamp(),
        'deviceId': await _firebaseMessaging.getToken(),
        'processed': false,
      });
    } catch (e) {
      // Silent fail
    }
  }

  /// Create heartbeat notification to keep system alive
  Future<void> _createHeartbeatNotification() async {
    try {
      if (_isInBackground) {
        await _flutterLocalNotificationsPlugin.show(
          888888,
          'Chat Service Running',
          'Background monitoring active',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'heartbeat_channel',
              'Heartbeat',
              channelDescription: 'Background service heartbeat',
              importance: Importance.min,
              priority: Priority.min,
              ongoing: true,
              autoCancel: false,
              silent: true,
            ),
          ),
        );
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _isInBackground = true;
        // Switch to aggressive background polling
        _startBackgroundPolling();
        break;
      case AppLifecycleState.resumed:
        _isInBackground = false;
        // Resume normal operation
        _restoreNormalOperation();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
        _isInBackground = true;
        _startBackgroundPolling();
        break;
    }
  }

  /// Start aggressive background polling
  void _startBackgroundPolling() {
    _primaryNotificationTimer?.cancel();
    _secondaryNotificationTimer?.cancel();
    _emergencyNotificationTimer?.cancel();

    _isInBackground = true;
    _isOfflineMode = true;

    // Force send any pending grouped notifications immediately when going to background
    _flushPendingNotifications();

    // Primary timer - every 3 seconds
    _primaryNotificationTimer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) async {
        await processPendingNotifications();
        await _pollForNewMessages();
        await _processNotificationQueue();
      },
    );

    // Secondary backup timer - every 5 seconds
    _secondaryNotificationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) async {
        await _pollForNewMessages();
        await _createBackupNotificationRequests();
      },
    );

    // Emergency fallback timer - every 10 seconds
    _emergencyNotificationTimer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) async {
        await _emergencyNotificationCheck();
      },
    );
  }

  /// Restore normal operation when app comes to foreground
  void _restoreNormalOperation() {
    _primaryNotificationTimer?.cancel();
    _secondaryNotificationTimer?.cancel();
    _emergencyNotificationTimer?.cancel();

    _isInBackground = false;
    _isOfflineMode = false;

    // Restart Firestore listener
    _setupFirestoreListener();
    // Resume normal timer
    _startNotificationProcessingTimer();
  }

  /// Enable offline persistence for Firestore
  Future<void> _enableOfflinePersistence() async {
    try {
      await _firestore.enablePersistence(
        const PersistenceSettings(synchronizeTabs: true),
      );
    } catch (e) {
      // Persistence might already be enabled
    }
  }

  /// Start timer to process pending notifications
  void _startNotificationProcessingTimer() {
    _primaryNotificationTimer?.cancel();
    _primaryNotificationTimer = Timer.periodic(
      const Duration(seconds: 10), // More frequent checking
      (timer) async {
        await processPendingNotifications();
        await _pollForNewMessages();
      },
    );
  }

  /// Initialize Flutter Local Notifications
  Future<void> _initializeLocalNotifications() async {
    // Android notification settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _chatChannelId,
      _chatChannelName,
      description: _chatChannelDescription,
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      showBadge: true,
      enableLights: true,
      ledColor: Color(0xFF00FF00),
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Initialize Firebase Messaging
  Future<void> _initializeFirebaseMessaging() async {
    try {
      // Request permission for notifications with all options
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      // Only proceed if permission is granted
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Configure Firebase Messaging to handle background messages
        await _firebaseMessaging.setAutoInitEnabled(true);

        // Get FCM token
        String? token = await _firebaseMessaging.getToken();

        // Save token to Firestore for sending targeted notifications
        if (token != null) {
          await _saveFCMToken(token);
        }

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen(_saveFCMToken);

        // Set background message handler
        FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler);

        // Handle foreground messages
        _foregroundMessageSubscription =
            FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle notification taps when app is in background/terminated
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // Handle notification tap when app is terminated
        RemoteMessage? initialMessage =
            await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }

        // Subscribe to topic for admin notifications
        await _firebaseMessaging.subscribeToTopic('admin_notifications');
      }
    } catch (e) {
      // Silent fail in background mode
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveFCMToken(String token) async {
    try {
      await _firestore.collection('fcm_tokens').doc(token).set({
        'token': token,
        'platform': 'android',
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving FCM token: $e');
      }
    }
  }

  /// Setup Firestore listener for new messages
  Future<void> _setupFirestoreListener() async {
    // Get current time and subtract a small buffer to ensure we catch new messages
    _lastProcessedTimestamp =
        DateTime.now().subtract(const Duration(minutes: 1));

    // Listen to all documents in the chat-messages collection for changes
    // Use includeMetadataChanges to detect connection state
    _messagesSubscription = _firestore
        .collection('chat-messages')
        .snapshots(includeMetadataChanges: true)
        .listen(
      _handleDocumentChanges,
      onError: (error) {
        // Connection lost, fall back to polling
        _startOfflinePolling();
      },
    );
  }

  /// Start offline polling when Firestore connection is lost
  void _startOfflinePolling() {
    _secondaryNotificationTimer?.cancel();
    _secondaryNotificationTimer = Timer.periodic(
      const Duration(seconds: 15),
      (timer) async {
        await _pollForNewMessages();
        await processPendingNotifications();
      },
    );
  }

  /// Poll for new messages when offline
  Future<void> _pollForNewMessages() async {
    try {
      final cutoffTime = _lastProcessedTimestamp ??
          DateTime.now().subtract(const Duration(minutes: 5));

      final snapshot = await _firestore
          .collection('chat-messages')
          .where('lastUpdated', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .get(const GetOptions(source: Source.cache));

      for (var doc in snapshot.docs) {
        final docData = doc.data();
        if (docData.containsKey('messages')) {
          final messagesMap = docData['messages'] as Map<String, dynamic>?;
          if (messagesMap != null) {
            for (var messageEntry in messagesMap.entries) {
              final messageId = messageEntry.key;
              final messageData = messageEntry.value as Map<String, dynamic>;

              if (!_processedMessageIds.contains(messageId)) {
                try {
                  final message = ChatMessage.fromMap(messageId, {
                    ...messageData,
                    'userId': docData['userId'],
                    'userName': docData['userName'],
                  });

                  if ((_lastProcessedTimestamp == null ||
                          message.timestamp
                              .isAfter(_lastProcessedTimestamp!)) &&
                      message.sender != 'support') {
                    _processedMessageIds.add(message.id);
                    await _showLocalNotification(message);
                    _lastProcessedTimestamp = message.timestamp;
                  }
                } catch (e) {
                  // Skip invalid messages
                }
              }
            }
          }
        }
      }
    } catch (e) {
      // Silent fail - will try again next poll
    }
  }

  /// Process queued notifications
  Future<void> _processNotificationQueue() async {
    if (_pendingNotificationQueue.isEmpty) return;

    final List<Map<String, dynamic>> toProcess =
        List.from(_pendingNotificationQueue);
    _pendingNotificationQueue.clear();

    for (final notification in toProcess) {
      try {
        await _showLocalNotificationFromData(notification);
        _messageProcessingHistory[notification['messageId']] = DateTime.now();
      } catch (e) {
        // Re-queue if failed
        _pendingNotificationQueue.add(notification);
      }
    }
  }

  /// Create backup notification requests in multiple places
  Future<void> _createBackupNotificationRequests() async {
    if (!_isInBackground && !_isOfflineMode) return;

    try {
      // Check for new messages in the last minute
      final now = DateTime.now();
      final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

      final snapshot = await _firestore
          .collection('chat-messages')
          .where('lastUpdated', isGreaterThan: Timestamp.fromDate(oneMinuteAgo))
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final messages = data['messages'] as Map<String, dynamic>? ?? {};

        for (final entry in messages.entries) {
          final messageId = entry.key;
          final messageData = entry.value as Map<String, dynamic>;

          if (!_messageProcessingHistory.containsKey(messageId)) {
            _pendingNotificationQueue.add({
              'messageId': messageId,
              'sender': messageData['sender'] ?? '',
              'message': messageData['message'] ?? '',
              'timestamp': messageData['timestamp'],
              'userName': data['userName'] ?? 'Unknown User',
            });
          }
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// Emergency notification check as final fallback
  Future<void> _emergencyNotificationCheck() async {
    if (!_isInBackground) return;

    try {
      // Create multiple notification requests with different timestamps
      final now = DateTime.now();

      for (int i = 0; i < 3; i++) {
        await _firestore.collection('emergency_notifications').add({
          'type': 'background_check',
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': now.add(Duration(seconds: i)).toIso8601String(),
          'processed': false,
          'checkId': '${now.millisecondsSinceEpoch}_$i',
        });
      }

      // Also trigger local notification to test system when in background
      if (_isOfflineMode) {
        await _flutterLocalNotificationsPlugin.show(
          999 + (now.millisecondsSinceEpoch % 1000),
          'Background Service Active',
          'Monitoring for new messages...',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'system_status',
              'System Status',
              channelDescription: 'Background service status notifications',
              importance: Importance.low,
              priority: Priority.low,
              ongoing: true,
            ),
          ),
        );
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// Show local notification from data map with grouping support
  Future<void> _showLocalNotificationFromData(Map<String, dynamic> data) async {
    try {
      // Create a ChatMessage object from the data
      final message = ChatMessage(
        id: data['messageId'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        sender: data['sender'] ?? 'Unknown',
        userName: data['userName'] ?? data['sender'] ?? 'Unknown User',
        message: data['message'] ?? '',
        timestamp: data['timestamp'] is Timestamp
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
        userId: data['userId'] ?? 'unknown',
      );

      // Use the grouped notification system
      await _showLocalNotification(message);
    } catch (e) {
      // Fallback to simple notification
      try {
        final int notificationId = data['messageId'].hashCode.abs();
        final String title =
            'New message from ${data['userName'] ?? 'Unknown User'}';
        final String body = data['message'] ?? '';

        await _flutterLocalNotificationsPlugin.show(
          notificationId,
          title,
          body.length > 100 ? '${body.substring(0, 100)}...' : body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _chatChannelId,
              _chatChannelName,
              channelDescription: _chatChannelDescription,
              importance: Importance.high,
              priority: Priority.high,
              autoCancel: true,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.message,
            ),
          ),
        );
      } catch (fallbackError) {
        // Silent fail
      }
    }
  }

  /// Handle document changes in the chat-messages collection
  void _handleDocumentChanges(QuerySnapshot snapshot) {
    if (kDebugMode) {
      print(
          'Firestore snapshot received with ${snapshot.docs.length} documents');
    }

    try {
      // Process document changes
      for (var docChange in snapshot.docChanges) {
        if (kDebugMode) {
          print(
              'Document change type: ${docChange.type}, doc ID: ${docChange.doc.id}');
        }

        if (docChange.type == DocumentChangeType.modified ||
            docChange.type == DocumentChangeType.added) {
          final docData = docChange.doc.data() as Map<String, dynamic>?;

          if (docData != null && docData.containsKey('messages')) {
            final messagesMap = docData['messages'] as Map<String, dynamic>?;

            if (messagesMap != null) {
              if (kDebugMode) {
                print(
                    'Processing ${messagesMap.length} messages in document ${docChange.doc.id}');
              }

              // Process each message in the messages map
              for (var messageEntry in messagesMap.entries) {
                final messageId = messageEntry.key;
                final messageData = messageEntry.value as Map<String, dynamic>;

                try {
                  // Create a ChatMessage object
                  final message = ChatMessage.fromMap(messageId, {
                    ...messageData,
                    'userId': docData['userId'],
                    'userName': docData['userName'],
                  });

                  if (kDebugMode) {
                    print(
                        'Checking message: ${message.id}, sender: ${message.sender}, timestamp: ${message.timestamp.toIso8601String()}');
                    print(
                        'Already processed: ${_processedMessageIds.contains(message.id)}');
                    if (_lastProcessedTimestamp != null) {
                      print(
                          'Is newer than last processed: ${message.timestamp.isAfter(_lastProcessedTimestamp!)}');
                    }
                  }

                  // Only show notification for new messages that:
                  // 1. Haven't been processed before
                  // 2. Are newer than our last processed timestamp
                  // 3. Are not from the current user (if we have user identification)
                  // 4. Are not from support (admin's own messages)
                  if (!_processedMessageIds.contains(message.id) &&
                      (_lastProcessedTimestamp == null ||
                          message.timestamp
                              .isAfter(_lastProcessedTimestamp!)) &&
                      (_currentUserId == null ||
                          message.userId != _currentUserId) &&
                      message.sender != 'support') {
                    _processedMessageIds.add(message.id);
                    _showLocalNotification(message);

                    // Update last processed timestamp
                    _lastProcessedTimestamp = message.timestamp;

                    if (kDebugMode) {
                      print(
                          '✅ Showing notification for message: ${message.id} from ${message.sender}');
                      print('Message content: ${message.message}');
                    }
                  } else if (kDebugMode) {
                    print(
                        '❌ Skipping message: ${message.id} - reason: ${_getSkipReason(message)}');
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print('Error parsing message $messageId: $e');
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling document changes: $e');
      }
    }
  }

  /// Helper method to determine why a message was skipped (for debugging)
  String _getSkipReason(ChatMessage message) {
    if (_processedMessageIds.contains(message.id)) {
      return 'already processed';
    }
    if (_lastProcessedTimestamp != null &&
        !message.timestamp.isAfter(_lastProcessedTimestamp!)) {
      return 'timestamp too old';
    }
    if (_currentUserId != null && message.userId == _currentUserId) {
      return 'from current user';
    }
    if (message.sender == 'support') {
      return 'from support';
    }
    return 'unknown';
  }

  /// Handle foreground Firebase messages
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Received foreground message: ${message.notification?.title}');
    }

    // Show local notification for foreground messages
    _showFirebaseNotification(message);
  }

  /// Show local notification for Firestore messages with grouping
  Future<void> _showLocalNotification(ChatMessage message) async {
    try {
      final String userKey = message.userName ?? message.sender;

      // Cancel existing timer for this user if it exists
      _notificationTimers[userKey]?.cancel();

      // Add message to pending notifications for this user
      if (!_pendingNotificationsByUser.containsKey(userKey)) {
        _pendingNotificationsByUser[userKey] = [];
      }
      _pendingNotificationsByUser[userKey]!.add(message);

      // Set a timer to send grouped notification after delay
      _notificationTimers[userKey] =
          Timer(_notificationGroupingDelay, () async {
        await _sendGroupedNotification(userKey);
      });

      if (kDebugMode) {
        print(
            'Message queued for grouping from $userKey. Total pending: ${_pendingNotificationsByUser[userKey]!.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error queueing notification for grouping: $e');
      }
      // Fallback to individual notification
      await _sendIndividualNotification(message);
    }
  }

  /// Send grouped notification for a user
  Future<void> _sendGroupedNotification(String userKey) async {
    try {
      final messages = _pendingNotificationsByUser[userKey];
      if (messages == null || messages.isEmpty) return;

      // Remove from pending and timer
      _pendingNotificationsByUser.remove(userKey);
      _notificationTimers.remove(userKey);

      // Sort messages by timestamp
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Create grouped notification
      final String title;
      final String body;
      final int notificationId = userKey.hashCode.abs();

      if (messages.length == 1) {
        // Single message - use normal format
        final message = messages.first;
        title = message.userName?.isNotEmpty == true
            ? message.userName!
            : (message.sender.isNotEmpty ? message.sender : 'New Message');
        body = message.message.length > 100
            ? '${message.message.substring(0, 100)}...'
            : message.message;
      } else {
        // Multiple messages - use grouped format
        title = '${messages.length} new messages from $userKey';

        // Create summary of messages
        final StringBuffer bodyBuffer = StringBuffer();
        for (int i = 0; i < messages.length && i < 3; i++) {
          if (i > 0) bodyBuffer.write('\n');
          final msg = messages[i].message;
          bodyBuffer
              .write(msg.length > 50 ? '${msg.substring(0, 50)}...' : msg);
        }

        if (messages.length > 3) {
          bodyBuffer.write('\nand ${messages.length - 3} more messages...');
        }

        body = bodyBuffer.toString();
      }

      // Create enhanced notification details for grouped messages
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _chatChannelId,
        _chatChannelName,
        channelDescription: _chatChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: messages.length > 1
            ? InboxStyleInformation(
                messages
                    .map((m) => m.message.length > 60
                        ? '${m.message.substring(0, 60)}...'
                        : m.message)
                    .toList(),
                contentTitle: title,
                summaryText: '${messages.length} messages',
              )
            : BigTextStyleInformation(
                body,
                contentTitle: title,
              ),
        autoCancel: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        groupKey: 'chat_group_$userKey',
        setAsGroupSummary: messages.length > 1,
        number: messages.length,
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      // Show grouped notification
      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: jsonEncode({
          'userKey': userKey,
          'messageCount': messages.length,
          'messageIds': messages.map((m) => m.id).toList(),
          'latestTimestamp': messages.last.timestamp.toIso8601String(),
        }),
      );

      if (kDebugMode) {
        print(
            'Grouped notification sent for $userKey with ${messages.length} messages');
        print('Title: $title');
        print('Body: $body');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending grouped notification: $e');
      }

      // Fallback: send individual notifications
      final messages = _pendingNotificationsByUser[userKey];
      if (messages != null) {
        for (final message in messages) {
          await _sendIndividualNotification(message);
        }
        _pendingNotificationsByUser.remove(userKey);
        _notificationTimers.remove(userKey);
      }
    }
  }

  /// Send individual notification (fallback method)
  Future<void> _sendIndividualNotification(ChatMessage message) async {
    try {
      // Create notification details with enhanced settings
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _chatChannelId,
        _chatChannelName,
        channelDescription: _chatChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(''),
        autoCancel: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      // Create notification title and body
      final String title = message.userName?.isNotEmpty == true
          ? message.userName!
          : (message.sender.isNotEmpty ? message.sender : 'New Message');
      final String body = message.message.length > 100
          ? '${message.message.substring(0, 100)}...'
          : message.message;

      // Use timestamp-based ID to ensure uniqueness
      final int notificationId =
          message.timestamp.millisecondsSinceEpoch % 2147483647;

      // Show notification
      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: jsonEncode({
          'messageId': message.id,
          'sender': message.sender,
          'userName': message.userName,
          'timestamp': message.timestamp.toIso8601String(),
        }),
      );

      if (kDebugMode) {
        print(
            'Individual notification shown for message: ${message.id} - $title: $body');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error showing individual notification: $e');
      }
    }
  }

  /// Force send all pending grouped notifications immediately
  void _flushPendingNotifications() {
    try {
      // Send all pending grouped notifications immediately
      final userKeys = List<String>.from(_pendingNotificationsByUser.keys);
      for (final userKey in userKeys) {
        // Cancel the timer and send immediately
        _notificationTimers[userKey]?.cancel();
        _notificationTimers.remove(userKey);
        _sendGroupedNotification(userKey);
      }

      if (kDebugMode && userKeys.isNotEmpty) {
        print('Flushed ${userKeys.length} pending grouped notifications');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error flushing pending notifications: $e');
      }
    }
  }

  /// Show notification for Firebase messages
  Future<void> _showFirebaseNotification(RemoteMessage message) async {
    try {
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _chatChannelId,
        _chatChannelName,
        channelDescription: _chatChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        autoCancel: true,
        ongoing: false,
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        ticker: 'New message received',
        when: DateTime.now().millisecondsSinceEpoch,
        enableLights: true,
        ledColor: const Color(0xFF00FF00),
        ledOnMs: 1000,
        ledOffMs: 500,
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      final String title =
          message.notification?.title ?? message.data['title'] ?? 'New Message';
      final String body = message.notification?.body ??
          message.data['body'] ??
          'You have a new message';

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch % 2147483647,
        title,
        body,
        notificationDetails,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      // Silent fail in background mode
    }
  }

  /// Handle notification taps
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(response.payload!);
        _navigateToChat(data);
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing notification payload: $e');
        }
      }
    }
  }

  /// Handle Firebase notification taps
  void _handleNotificationTap(RemoteMessage message) {
    _navigateToChat(message.data);
  }

  /// Navigate to chat screen
  void _navigateToChat(Map<String, dynamic> data) {
    // You can implement navigation logic here
    // For example, navigate to specific chat thread
    if (kDebugMode) {
      print('Navigating to chat with data: $data');
    }

    // Example navigation (you'll need to adapt this to your app structure):
    // Navigator.of(context).pushNamed('/chat', arguments: data);
  }

  /// Send notification to all FCM tokens about new chat message
  Future<void> sendChatNotificationToAllTokens({
    required String title,
    required String body,
    required String messageId,
    required String sender,
    required String timestamp,
  }) async {
    try {
      // Get all FCM tokens
      final tokensSnapshot = await _firestore.collection('fcm_tokens').get();

      // Create notification data
      final data = {
        'type': 'chat_message',
        'messageId': messageId,
        'sender': sender,
        'timestamp': timestamp,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      };

      // Send to each token by creating a notification request
      for (var doc in tokensSnapshot.docs) {
        final token = doc.data()['token'] as String?;
        if (token != null) {
          await _createNotificationRequest(
            token: token,
            title: title,
            body: body,
            data: data,
          );
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// Process pending notification requests (call this periodically)
  Future<void> processPendingNotifications() async {
    try {
      final requests = await _firestore
          .collection('notification_requests')
          .where('processed', isEqualTo: false)
          .limit(10)
          .get();

      for (var doc in requests.docs) {
        final data = doc.data();
        final notification = data['notification'] as Map<String, dynamic>?;
        final requestData = data['data'] as Map<String, dynamic>?;

        if (notification != null) {
          // Create a simulated FCM message
          final remoteMessage = _createSimulatedFCMMessage(
            title: notification['title'] ?? 'New Message',
            body: notification['body'] ?? '',
            data: requestData ?? {},
          );

          // Show the notification
          await _showFirebaseNotification(remoteMessage);

          // Mark as processed
          await doc.reference.update({'processed': true});
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// Create a simulated FCM message for local processing
  RemoteMessage _createSimulatedFCMMessage({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    // This creates a mock RemoteMessage for local processing
    // In a real implementation, this would come from FCM server
    return RemoteMessage(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      data: data.map((key, value) => MapEntry(key, value.toString())),
      notification: RemoteNotification(
        title: title,
        body: body,
      ),
      sentTime: DateTime.now(),
    );
  }

  Future<void> _createNotificationRequest({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      await _firestore.collection('notification_requests').add({
        'token': token,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'processed': false,
      });
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> sendNotificationToAll({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get all FCM tokens
      final tokensSnapshot = await _firestore.collection('fcm_tokens').get();

      for (var doc in tokensSnapshot.docs) {
        final token = doc.data()['token'] as String?;
        if (token != null) {
          await _sendFCMMessage(
            token: token,
            title: title,
            body: body,
            data: data,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending notifications: $e');
      }
    }
  }

  /// Send FCM message to specific token
  Future<void> _sendFCMMessage({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Note: This requires a server-side implementation or Cloud Functions
    // as Flutter cannot directly send FCM messages due to security restrictions

    if (kDebugMode) {
      print('Would send FCM message to token: $token');
      print('Title: $title, Body: $body');
    }
  }

  /// Clear all notifications including grouped ones
  Future<void> clearAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();

    // Also clear any pending grouped notifications
    for (final timer in _notificationTimers.values) {
      timer.cancel();
    }
    _notificationTimers.clear();
    _pendingNotificationsByUser.clear();
  }

  /// Clear specific notification
  Future<void> clearNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Clear notifications for a specific user
  Future<void> clearNotificationsForUser(String userKey) async {
    // Cancel pending grouped notification
    _notificationTimers[userKey]?.cancel();
    _notificationTimers.remove(userKey);
    _pendingNotificationsByUser.remove(userKey);

    // Cancel the actual notification (using userKey hash as ID)
    final notificationId = userKey.hashCode.abs();
    await _flutterLocalNotificationsPlugin.cancel(notificationId);
  }

  /// Force reinitialize the entire notification service
  Future<void> reinitialize() async {
    dispose();
    await initialize();
  }

  /// Restart the Firestore listener (useful if connection is lost)
  Future<void> restartFirestoreListener() async {
    await _messagesSubscription?.cancel();
    await _setupFirestoreListener();
  }

  /// Set current user ID to filter out own messages
  void setCurrentUserId(String? userId) {
    _currentUserId = userId;
  }

  /// Test notification - public method for testing
  Future<void> testNotification({
    String title = 'Test Notification',
    String body = 'This is a test notification',
  }) async {
    final testMessage = ChatMessage(
      id: 'test-${DateTime.now().millisecondsSinceEpoch}',
      sender: 'Test User',
      userName: title,
      message: body,
      timestamp: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      userId: 'test-user-id',
    );

    await _showLocalNotification(testMessage);
  }

  /// Test grouped notifications - create multiple messages from same user
  Future<void> testGroupedNotifications({
    String userName = 'Test User',
    int messageCount = 3,
  }) async {
    for (int i = 0; i < messageCount; i++) {
      final testMessage = ChatMessage(
        id: 'test-group-${DateTime.now().millisecondsSinceEpoch}-$i',
        sender: userName,
        userName: userName,
        message: 'Test message ${i + 1} from $userName',
        timestamp: DateTime.now().add(Duration(milliseconds: i * 100)),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        userId: 'test-user-id-$userName',
      );

      await _showLocalNotification(testMessage);

      // Small delay between messages to simulate real chat
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (kDebugMode) {
      print(
          'Created $messageCount test messages from $userName for grouping test');
    }
  }

  /// Test multiple users - create messages from different users
  Future<void> testMultipleUserNotifications() async {
    final users = ['Alice', 'Bob', 'Charlie'];

    for (int userIndex = 0; userIndex < users.length; userIndex++) {
      final userName = users[userIndex];

      // Each user sends 2-3 messages
      final messageCount = 2 + (userIndex % 2);

      for (int i = 0; i < messageCount; i++) {
        final testMessage = ChatMessage(
          id: 'test-multi-${DateTime.now().millisecondsSinceEpoch}-$userName-$i',
          sender: userName,
          userName: userName,
          message: 'Message ${i + 1} from $userName',
          timestamp: DateTime.now()
              .add(Duration(milliseconds: (userIndex * 1000) + (i * 200))),
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
          userId: 'test-user-id-$userName',
        );

        await _showLocalNotification(testMessage);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Delay between users
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (kDebugMode) {
      print('Created test messages from ${users.length} different users');
    }
  }

  /// Clear processed messages cache (useful for testing)
  void clearProcessedMessagesCache() {
    _processedMessageIds.clear();
    _lastProcessedTimestamp =
        DateTime.now().subtract(const Duration(minutes: 1));
    if (kDebugMode) {
      print('Processed messages cache cleared');
    }
  }

  /// Debug method to check notification status
  Future<Map<String, dynamic>> getNotificationStatus() async {
    final settings = await _firebaseMessaging.getNotificationSettings();
    final token = await _firebaseMessaging.getToken();

    return {
      'isInitialized': _isInitialized,
      'authorizationStatus': settings.authorizationStatus.name,
      'fcmToken': token,
      'hasFirestoreListener': _messagesSubscription != null,
      'hasForegroundListener': _foregroundMessageSubscription != null,
      'processedMessageCount': _processedMessageIds.length,
      'processedMessageIds': _processedMessageIds.toList(),
      'lastProcessedTimestamp': _lastProcessedTimestamp?.toIso8601String(),
      'currentUserId': _currentUserId,
      'firestoreListenerActive': _messagesSubscription?.isPaused == false,
      'platform': Platform.operatingSystem,
      'pendingGroupedNotifications': _pendingNotificationsByUser.map(
        (user, messages) => MapEntry(user, {
          'messageCount': messages.length,
          'messageIds': messages.map((m) => m.id).toList(),
          'latestMessage': messages.isNotEmpty ? messages.last.message : null,
        }),
      ),
      'activeNotificationTimers': _notificationTimers.length,
      'isInBackground': _isInBackground,
      'isOfflineMode': _isOfflineMode,
    };
  }

  /// Get notification permission status
  Future<bool> isNotificationPermissionGranted() async {
    final settings = await _firebaseMessaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Request notification permission
  Future<bool> requestNotificationPermission() async {
    final settings = await _firebaseMessaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Dispose resources
  void dispose() {
    _messagesSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    _primaryNotificationTimer?.cancel();
    _secondaryNotificationTimer?.cancel();
    _emergencyNotificationTimer?.cancel();

    // Cancel all notification grouping timers
    for (final timer in _notificationTimers.values) {
      timer.cancel();
    }
    _notificationTimers.clear();

    WidgetsBinding.instance.removeObserver(this);
    _processedMessageIds.clear();
    _messageProcessingHistory.clear();
    _pendingNotificationQueue.clear();
    _pendingNotificationsByUser.clear();
    _isInitialized = false;
  }

  /// Get FCM token for this device
  Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }

  /// Subscribe to a topic for group notifications
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }
}
