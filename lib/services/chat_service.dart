import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';
import '../models/chat_models.dart';
import 'notification_service.dart';

class ChatService {
  static const String chatCollection = 'chat-messages';
  static const String fcmTokensCollection = 'fcm-tokens';
  static const String notificationHistoryCollection = 'notification-history';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Track notification history to prevent duplicates for old messages
  final Map<String, DateTime> _lastNotificationTimes = {};

  // Track currently open chat to prevent notifications for that user
  String? _currentlyOpenChatUserId;

  // Set the currently open chat user ID (call when opening a chat)
  void setCurrentlyOpenChat(String? userId) {
    _currentlyOpenChatUserId = userId;
    log('📱 Currently open chat set to userId: ${userId ?? "none"}');
  }

  // Get the currently open chat user ID
  String? getCurrentlyOpenChat() {
    return _currentlyOpenChatUserId;
  }

  // Send FCM notification for new message
  Future<void> _sendFCMNotificationForNewMessage({
    required String userName,
    required String message,
    required String messageId,
    required String timestamp,
  }) async {
    try {
      // Create immediate notification request
      await _createImmediateNotificationRequest(
        userName: userName,
        message: message,
        messageId: messageId,
        timestamp: timestamp,
      );

      // Also send to notification service
      await NotificationService().sendChatNotificationToAllTokens(
        title: 'New message from $userName',
        body:
            message.length > 100 ? '${message.substring(0, 100)}...' : message,
        messageId: messageId,
        sender: userName,
        timestamp: timestamp,
      );
    } catch (e) {
      log('Error sending FCM notification: $e');
    }
  }

  // Create immediate notification request for background processing
  Future<void> _createImmediateNotificationRequest({
    required String userName,
    required String message,
    required String messageId,
    required String timestamp,
  }) async {
    try {
      final now = DateTime.now();

      // Create 5 redundant notification requests with different strategies
      for (int i = 0; i < 5; i++) {
        // Strategy 1: Regular notification requests
        await _firestore.collection('notification_requests').add({
          'type': 'chat_message',
          'title': 'New message from $userName',
          'body': message.length > 100
              ? '${message.substring(0, 100)}...'
              : message,
          'data': {
            'messageId': messageId,
            'sender': userName,
            'timestamp': timestamp,
            'type': 'chat_message',
          },
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': now.add(Duration(seconds: i)).toIso8601String(),
          'processed': false,
          'retryCount': i,
          'strategy': 'primary',
        });

        // Strategy 2: Emergency notification requests
        await _firestore.collection('emergency_notifications').add({
          'type': 'chat_message_backup',
          'title': 'Message from $userName',
          'body':
              message.length > 50 ? '${message.substring(0, 50)}...' : message,
          'messageId': messageId,
          'sender': userName,
          'timestamp': timestamp,
          'createdAt':
              now.add(Duration(milliseconds: i * 500)).toIso8601String(),
          'processed': false,
          'priority': 'high',
          'strategy': 'emergency',
        });

        // Strategy 3: Background polling triggers
        await _firestore.collection('background_triggers').add({
          'action': 'check_messages',
          'userName': userName,
          'messageId': messageId,
          'timestamp': FieldValue.serverTimestamp(),
          'triggerTime': now.add(Duration(seconds: i + 2)).toIso8601String(),
          'processed': false,
          'strategy': 'polling',
        });
      }

      // Strategy 4: Direct FCM notification data in multiple collections
      for (String collection in [
        'fcm_queue',
        'notification_backup',
        'message_alerts'
      ]) {
        await _firestore.collection(collection).add({
          'type': 'new_message',
          'userName': userName,
          'message': message,
          'messageId': messageId,
          'timestamp': timestamp,
          'createdAt': now.toIso8601String(),
          'processed': false,
          'collection': collection,
        });
      }
    } catch (e) {
      log('Error creating notification request: $e');
    }
  }

  // Check if notification should be sent (prevents spam and old message notifications)
  bool _shouldSendNotification(
    String notificationKey, {
    Duration cooldown = const Duration(minutes: 1),
  }) {
    final now = DateTime.now();
    final lastTime = _lastNotificationTimes[notificationKey];

    if (lastTime == null) {
      _lastNotificationTimes[notificationKey] = now;
      return true;
    }

    if (now.difference(lastTime) > cooldown) {
      _lastNotificationTimes[notificationKey] = now;
      return true;
    }

    log('⏰ Notification cooldown active for: $notificationKey');
    return false;
  }

  // Store notification history in Firestore for persistence across app restarts
  Future<void> _storeNotificationHistory(
    String userName,
    String messageId,
    String type,
  ) async {
    try {
      await _firestore
          .collection(notificationHistoryCollection)
          .doc('${userName}_${type}_$messageId')
          .set({
        'userName': userName,
        'messageId': messageId,
        'type': type,
        'timestamp': Timestamp.now(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 6)),
        ),
      });
    } catch (e) {
      log('Error storing notification history: $e');
    }
  }

  // Check if notification was already sent for this message
  Future<bool> _wasNotificationSent(
    String userName,
    String messageId,
    String type,
  ) async {
    try {
      final doc = await _firestore
          .collection(notificationHistoryCollection)
          .doc('${userName}_${type}_$messageId')
          .get();
      return doc.exists;
    } catch (e) {
      log('Error checking notification history: $e');
      return false;
    }
  }

  // Cleanup expired notification history
  Future<void> _cleanupExpiredNotificationHistory() async {
    try {
      log('🧹 Cleaning up expired notification history...');

      final cutoffTime = DateTime.now().subtract(const Duration(hours: 6));
      final query = _firestore
          .collection(notificationHistoryCollection)
          .where('expiresAt', isLessThan: Timestamp.fromDate(cutoffTime));

      final snapshot = await query.get();
      int deletedCount = 0;

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
        deletedCount++;
      }

      log('✅ Cleaned up $deletedCount expired notification history entries');
    } catch (e) {
      log('Error cleaning up notification history: $e');
    }
  }

  // Store FCM token for a user
  Future<void> storeFCMToken(String userName, String token) async {
    try {
      await _firestore.collection(fcmTokensCollection).doc(userName).set({
        'token': token,
        'updatedAt': Timestamp.now(),
        'platform': 'mobile',
      }, SetOptions(merge: true));

      log('✅ FCM token stored for user: $userName');
    } catch (e) {
      log('❌ Error storing FCM token for $userName: $e');
    }
  }

  // Get FCM token for a user
  Future<String?> getFCMToken(String userName) async {
    try {
      final doc =
          await _firestore.collection(fcmTokensCollection).doc(userName).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['token'] as String?;
      }
      return null;
    } catch (e) {
      log('❌ Error getting FCM token for $userName: $e');
      return null;
    }
  }

  // Send FCM push notification to a specific user
  Future<void> sendFCMNotification({
    required String targetUserName,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final token = await getFCMToken(targetUserName);
      if (token == null) {
        log('⚠️ No FCM token found for user: $targetUserName');
        return;
      }

      // For a production app, you would have your own server endpoint
      // that uses the Firebase Admin SDK to send notifications securely.
      // Here's an example of what the payload would look like:

      final notificationPayload = {
        'to': token,
        'notification': {
          'title': title,
          'body': body,
          'icon': 'ic_notification',
          'sound': 'default',
        },
        'data': data ?? {},
        'android': {
          'notification': {'channel_id': 'chat_messages', 'priority': 'high'},
        },
        'apns': {
          'payload': {
            'aps': {'sound': 'default', 'badge': 1},
          },
        },
      };

      log('📱 FCM notification payload prepared for $targetUserName:');
      log('   Title: $title');
      log('   Body: $body');
      log('   Token: ${token.substring(0, 20)}...');
      log('   Data: $data');
      log('   Payload: ${jsonEncode(notificationPayload)}');

      // NOTE: In a real production app, you would send this to your server
      // which would then use the Firebase Admin SDK to send the notification.
      // Direct FCM API calls require server-side implementation for security.

      // Example server endpoint call:
      // final response = await http.post(
      //   Uri.parse('https://your-server.com/api/send-notification'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode(notificationPayload),
      // );

      log('✅ FCM notification would be sent to server for processing');
    } catch (e) {
      log('❌ Error preparing FCM notification for $targetUserName: $e');
    }
  }

  // Send FCM notification to admin topic for background notifications
  Future<void> _sendAdminTopicNotification({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Create a document in Firestore to trigger Cloud Function
      // This approach works better than direct FCM calls from client
      await _firestore.collection('admin_notifications').add({
        'title': title,
        'body': body,
        'data': data ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'processed': false,
      });

      log('📡 Admin notification queued for background processing');
      log('   Title: $title');
      log('   Body: $body');
      log('   Data: $data');
    } catch (e) {
      log('❌ Error queuing admin notification: $e');
    }
  }

  // Send admin notification request for background processing
  Future<void> sendAdminNotificationRequest({
    required String userName,
    required String userId,
    required String messageContent,
    required String messageId,
    required String threadId,
  }) async {
    try {
      await _firestore.collection('admin_notification_requests').add({
        'type': 'new_user_message',
        'userName': userName,
        'userId': userId,
        'messageContent': messageContent,
        'messageId': messageId,
        'threadId': threadId,
        'timestamp': FieldValue.serverTimestamp(),
        'processed': false,
        'notificationSent': false,
      });

      log('📨 Admin notification request stored for userId: $userId');
    } catch (e) {
      log('❌ Error storing admin notification request: $e');
    }
  }

  // Initialize FCM for current user
  Future<void> initializeFCMForUser(String userName) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await storeFCMToken(userName, token);
        log('🔑 FCM initialized for user: $userName');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        storeFCMToken(userName, newToken);
        log('🔄 FCM token refreshed for user: $userName');
      });
    } catch (e) {
      log('❌ Error initializing FCM for $userName: $e');
    }
  }

  // Generate anonymous user ID (matching JavaScript logic)
  String generateAnonymousUserId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000000000).toString().padLeft(9, '0');
    return 'user_${timestamp}_$random';
  }

  // Generate message ID (matching JavaScript logic)
  String generateMessageId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000000).toString().padLeft(6, '0');
    return 'msg_${timestamp}_$random';
  }

  // Create safe document ID from userName (matching JavaScript logic)
  String _createSafeDocId(String userName) {
    // First, try to find existing document with userName prefix
    return userName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  // Get chat document reference - try to find existing or create new
  Future<DocumentReference> _getChatDocRef(String userName) async {
    final safeUserName = _createSafeDocId(userName);

    // First, try to find an existing document that starts with this username
    final querySnapshot = await _firestore
        .collection(chatCollection)
        .where('userName', isEqualTo: userName)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      // Found existing document
      final existingDoc = querySnapshot.docs.first;
      log(
        '🔍 Found existing document: ${existingDoc.id} for userName: $userName',
      );
      return existingDoc.reference;
    }

    // Create new document with timestamp-based ID
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final docId = '${safeUserName}_$timestamp';
    log('🔑 Creating new document ID for userName: $userName → $docId');
    return _firestore.collection(chatCollection).doc(docId);
  }

  // Subscribe to all chat threads (for admin/support)
  Stream<List<ChatThread>> subscribeToAllChatThreads() {
    return _firestore
        .collection(chatCollection)
        .orderBy('lastUpdated', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ChatThread.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  // Subscribe to a specific chat thread by userId
  Stream<ChatThread?> subscribeToThread(String userId) {
    return _firestore
        .collection(chatCollection)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        return ChatThread.fromMap(doc.id, data);
      }
      return null;
    });
  }

  // Send a message to chat (creates or updates user's chat document)
  Future<Map<String, dynamic>> sendChatMessage(
    String message,
    String userId,
    String userName,
  ) async {
    try {
      final now = Timestamp.now();
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 2)),
      );

      final chatDocRef = await _getChatDocRef(userName);
      final chatDoc = await chatDocRef.get();

      final messageId = generateMessageId();
      final newMessage = {
        'sender': 'user',
        'message': message.trim(),
        'timestamp': now,
        'expiresAt': expiresAt,
      };

      if (chatDoc.exists) {
        // Update existing chat document
        final chatData = chatDoc.data() as Map<String, dynamic>;

        log('📝 Adding message to existing chat document for: $userName');
        log(
          '🔍 Current messages count: ${(chatData['messages'] as Map<String, dynamic>?)?.length ?? 0}',
        );

        // Add new message to the messages map
        await chatDocRef.update({
          'messages.$messageId': newMessage,
          'lastUpdated': now,
        });

        log(
          '✅ Message added to existing chat for user: $userName, message ID: $messageId',
        );

        // Send FCM notification for background delivery
        await _sendFCMNotificationForNewMessage(
          userName: userName,
          message: message,
          messageId: messageId,
          timestamp: now.millisecondsSinceEpoch.toString(),
        );

        // Send notification to admin about new user message (only once)
        try {
          // Check if notification was already sent for this message
          final wasNotificationSent = await _wasNotificationSent(
            userName,
            messageId,
            'user_message',
          );
          final notificationKey = 'admin_${userName}_message';

          // Don't send notification if this user's chat is currently open
          final isChatCurrentlyOpen = _currentlyOpenChatUserId == userId;

          if (!wasNotificationSent &&
              !isChatCurrentlyOpen &&
              _shouldSendNotification(notificationKey)) {
            log('Admin notification sent for message from: $userName');

            // Store notification history
            await _storeNotificationHistory(
              userName,
              messageId,
              'user_message',
            );

            // Also send FCM notification to admin topic for background notifications
            await _sendAdminTopicNotification(
              title: 'New message from $userName',
              body: message.length > 50
                  ? '${message.substring(0, 50)}...'
                  : message,
              data: {
                'type': 'new_user_message',
                'userName': userName,
                'userId': userId,
                'chatId': chatDocRef.id,
                'messageId': messageId,
                'timestamp': now.millisecondsSinceEpoch.toString(),
              },
            );
          } else {
            if (isChatCurrentlyOpen) {
              log(
                '⏭️ Skipping notification - chat with $userName is currently open',
              );
            } else {
              log(
                '⏭️ Skipping duplicate notification for message: $messageId',
              );
            }
          }
        } catch (e) {
          log('Error sending admin notification: $e');
          // Don't fail the message sending if notification fails
        }
      } else {
        // Create new chat document
        log('📄 Creating new chat document for: $userName');

        final newChatData = {
          'userName': userName,
          'userId': userId,
          'supportAgentName': 'Support Team',
          'createdAt': now,
          'lastUpdated': now,
          'messages': {messageId: newMessage},
        };

        await chatDocRef.set(newChatData);
        log(
          '✅ New chat document created for user: $userName, message ID: $messageId',
        );

        // Send FCM notification for background delivery
        await _sendFCMNotificationForNewMessage(
          userName: userName,
          message: message,
          messageId: messageId,
          timestamp: now.millisecondsSinceEpoch.toString(),
        );

        // Send notification to admin about new user message (for new chat)
        try {
          // Check if notification was already sent for this message
          const wasNotificationSent = false; // New chats are always unique
          final notificationKey = 'admin_${userName}_new_chat';

          // Don't send notification if this user's chat is currently open
          final isChatCurrentlyOpen = _currentlyOpenChatUserId == userId;

          if (!wasNotificationSent &&
              !isChatCurrentlyOpen &&
              _shouldSendNotification(notificationKey)) {
            log('Admin notification sent for new chat from: $userName');

            // Store notification history
            await _storeNotificationHistory(userName, messageId, 'new_chat');

            // Also send FCM notification to admin topic for background notifications
            await _sendAdminTopicNotification(
              title: 'New chat started by $userName',
              body: message.length > 50
                  ? '${message.substring(0, 50)}...'
                  : message,
              data: {
                'type': 'new_chat_started',
                'userName': userName,
                'userId': userId,
                'chatId': chatDocRef.id,
                'messageId': messageId,
                'timestamp': now.millisecondsSinceEpoch.toString(),
              },
            );
          } else if (isChatCurrentlyOpen) {
            log(
              '⏭️ Skipping new chat notification - chat with $userName is currently open',
            );
          }
        } catch (e) {
          log('Error sending admin notification for new chat: $e');
          // Don't fail the message sending if notification fails
        }
      }

      return {
        'success': true,
        'messageId': messageId,
        'userName': userName,
        'chatDocId': chatDocRef.id,
      };
    } catch (error) {
      log('Error sending message: $error');
      rethrow;
    }
  }

  // Send support response to a thread by userId
  Future<Map<String, dynamic>> sendSupportResponse(
    String userId,
    String message,
  ) async {
    try {
      final now = Timestamp.now();
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 2)),
      );

      // First find the existing chat document
      final querySnapshot = await _firestore
          .collection(chatCollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Chat document not found for userId: $userId');
      }

      final chatDocRef = querySnapshot.docs.first.reference;
      final chatData = querySnapshot.docs.first.data();
      final userName = chatData['userName'] ?? 'Unknown User';
      final messageId = generateMessageId();
      final newMessage = {
        'sender': 'support',
        'message': message.trim(),
        'timestamp': now,
        'expiresAt': expiresAt,
      };

      // Add support message to the messages map
      await chatDocRef.update({
        'messages.$messageId': newMessage,
        'lastUpdated': now,
      });

      // NOTE: No notification sent for support responses since these are admin's own messages
      // The user will be notified via the GlobalNotificationManager if their app is closed
      // or via real-time UI updates if their app is open

      log(
        'Support response sent to chat for userId: $userId (userName: $userName), message ID: $messageId',
      );
      return {
        'success': true,
        'messageId': messageId,
        'userId': userId,
        'userName': userName,
        'chatDocId': chatDocRef.id,
      };
    } catch (error) {
      log('Error sending support response: $error');
      rethrow;
    }
  }

  // Edit admin/support message
  Future<Map<String, dynamic>> editSupportMessage(
    String userId,
    String messageId,
    String newMessage,
  ) async {
    try {
      // Find the existing chat document
      final querySnapshot = await _firestore
          .collection(chatCollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Chat document not found for userId: $userId');
      }

      final chatDocRef = querySnapshot.docs.first.reference;
      final chatData = querySnapshot.docs.first.data();

      // Check if message exists and is from support
      final messages = chatData['messages'] as Map<String, dynamic>?;
      if (messages == null || !messages.containsKey(messageId)) {
        throw Exception('Message not found');
      }

      final messageData = messages[messageId] as Map<String, dynamic>;
      if (messageData['sender'] != 'support') {
        throw Exception('Only support messages can be edited');
      }

      // Update the message
      final updatedMessage = {
        ...messageData,
        'message': newMessage,
        'editedAt': Timestamp.now(),
        'edited': true,
      };

      await chatDocRef.update({
        'messages.$messageId': updatedMessage,
        'lastUpdated': Timestamp.now(),
      });

      log('Support message edited: $messageId for userId: $userId');
      return {'success': true, 'messageId': messageId, 'userId': userId};
    } catch (error) {
      log('Error editing support message: $error');
      rethrow;
    }
  }

  // Delete admin/support message
  Future<Map<String, dynamic>> deleteSupportMessage(
    String userId,
    String messageId,
  ) async {
    try {
      // Find the existing chat document
      final querySnapshot = await _firestore
          .collection(chatCollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Chat document not found for userId: $userId');
      }

      final chatDocRef = querySnapshot.docs.first.reference;
      final chatData = querySnapshot.docs.first.data();

      // Check if message exists and is from support
      final messages = chatData['messages'] as Map<String, dynamic>?;
      if (messages == null || !messages.containsKey(messageId)) {
        throw Exception('Message not found');
      }

      final messageData = messages[messageId] as Map<String, dynamic>;
      if (messageData['sender'] != 'support') {
        throw Exception('Only support messages can be deleted');
      }

      // Delete the message
      await chatDocRef.update({
        'messages.$messageId': FieldValue.delete(),
        'lastUpdated': Timestamp.now(),
      });

      log('Support message deleted: $messageId for userId: $userId');
      return {'success': true, 'messageId': messageId, 'userId': userId};
    } catch (error) {
      log('Error deleting support message: $error');
      rethrow;
    }
  }

  // Delete expired chat messages (older than 2 hours)
  Future<Map<String, dynamic>> cleanupExpiredMessages() async {
    try {
      log('🧹 Starting cleanup of expired chat messages...');

      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 2));

      final query = _firestore
          .collection(chatCollection)
          .where('lastUpdated', isLessThan: Timestamp.fromDate(cutoffTime));

      final querySnapshot = await query.get();
      final processedChats = <Map<String, dynamic>>[];
      int totalDeletedMessages = 0;

      // Also cleanup expired notification history
      await _cleanupExpiredNotificationHistory();

      // Process each chat document
      for (final docSnapshot in querySnapshot.docs) {
        try {
          final chatData = docSnapshot.data();
          final messages = chatData['messages'] as Map<String, dynamic>? ?? {};
          int deletedMessagesCount = 0;
          Map<String, dynamic> updatedMessages = {};

          // Check each message for expiration
          messages.forEach((msgId, msgData) {
            final messageData = msgData as Map<String, dynamic>;
            final expiresAt = _parseFirebaseTimestamp(messageData['expiresAt']);

            if (expiresAt.isAfter(now)) {
              // Keep non-expired messages
              updatedMessages[msgId] = msgData;
            } else {
              // Count expired messages for deletion
              deletedMessagesCount++;
            }
          });

          if (deletedMessagesCount > 0) {
            if (updatedMessages.isEmpty) {
              // Delete entire document if no messages remain
              await docSnapshot.reference.delete();
              log(
                '🗑️ Deleted entire chat document: ${docSnapshot.id} ($deletedMessagesCount expired messages)',
              );
            } else {
              // Update document with remaining messages
              await docSnapshot.reference.update({
                'messages': updatedMessages,
                'lastUpdated': Timestamp.now(),
              });
              log(
                '🧹 Cleaned $deletedMessagesCount expired messages from chat: ${docSnapshot.id}',
              );
            }

            totalDeletedMessages += deletedMessagesCount;
            processedChats.add({
              'id': docSnapshot.id,
              'userName': chatData['userName'],
              'deletedMessages': deletedMessagesCount,
              'remainingMessages': updatedMessages.length,
            });
          }
        } catch (deleteError) {
          log('❌ Error processing chat ${docSnapshot.id}: $deleteError');
        }
      }

      log(
        '✅ Cleanup completed. Processed ${processedChats.length} chats, deleted $totalDeletedMessages expired messages.',
      );

      return {
        'success': true,
        'deletedCount': totalDeletedMessages,
        'processedChats': processedChats,
      };
    } catch (error) {
      log('❌ Error during cleanup: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  // Helper method to parse Firebase timestamp
  DateTime _parseFirebaseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    if (timestamp is String) {
      return DateTime.parse(timestamp);
    }
    if (timestamp is DateTime) {
      return timestamp;
    }
    return DateTime.now();
  }

  // Delete a user's chat document (for reset functionality)
  Future<Map<String, dynamic>> deleteChatThread(String userId) async {
    try {
      log('🗑️ Deleting chat document for userId: $userId');

      // Find the existing chat document
      final querySnapshot = await _firestore
          .collection(chatCollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final chatDocRef = querySnapshot.docs.first.reference;
        final chatData = querySnapshot.docs.first.data();
        final userName = chatData['userName'] ?? 'Unknown User';
        await chatDocRef.delete();
        log('✅ Chat document deleted successfully');
        return {
          'success': true,
          'userId': userId,
          'userName': userName,
          'chatDocId': chatDocRef.id,
        };
      } else {
        log('ℹ️ No chat document found to delete for userId: $userId');
        return {
          'success': true,
          'userId': userId,
          'message': 'No chat document found',
        };
      }
    } catch (error) {
      log('❌ Error deleting chat document: $error');
      rethrow;
    }
  }

  // Get statistics about chat threads
  Future<Map<String, int>> getChatStatistics() async {
    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));

      // Get all threads
      final allThreadsSnapshot =
          await _firestore.collection(chatCollection).get();

      // Get recent threads (last 24 hours)
      final recentThreadsSnapshot = await _firestore
          .collection(chatCollection)
          .where('lastUpdated', isGreaterThan: Timestamp.fromDate(last24Hours))
          .get();

      // Count threads with unread messages
      int threadsWithUnreadMessages = 0;
      int totalMessages = 0;
      int totalUserMessages = 0;
      int totalSupportMessages = 0;

      for (final doc in allThreadsSnapshot.docs) {
        final thread = ChatThread.fromMap(doc.id, doc.data());

        if (thread.hasUnreadUserMessages) {
          threadsWithUnreadMessages++;
        }

        totalMessages += thread.messages.length;
        totalUserMessages +=
            thread.messages.where((msg) => msg.isFromUser).length;
        totalSupportMessages +=
            thread.messages.where((msg) => msg.isFromSupport).length;
      }

      return {
        'totalThreads': allThreadsSnapshot.docs.length,
        'recentThreads': recentThreadsSnapshot.docs.length,
        'threadsWithUnreadMessages': threadsWithUnreadMessages,
        'totalMessages': totalMessages,
        'totalUserMessages': totalUserMessages,
        'totalSupportMessages': totalSupportMessages,
      };
    } catch (error) {
      log('Error getting chat statistics: $error');
      return {};
    }
  }

  // Mark thread as read (admin feature) by userId
  Future<void> markThreadAsRead(String userId) async {
    try {
      // Find the existing chat document
      final querySnapshot = await _firestore
          .collection(chatCollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final chatDocRef = querySnapshot.docs.first.reference;
        await chatDocRef.update({'lastViewedBySupport': Timestamp.now()});
      } else {
        log('No chat document found for userId: $userId');
      }
    } catch (error) {
      log('Error marking thread as read: $error');
      rethrow;
    }
  }

  // Search threads by user name or message content
  Stream<List<ChatThread>> searchThreads(String searchQuery) {
    if (searchQuery.isEmpty) {
      return subscribeToAllChatThreads();
    }

    return _firestore
        .collection(chatCollection)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map((snapshot) {
      final allThreads = snapshot.docs.map((doc) {
        return ChatThread.fromMap(doc.id, doc.data());
      }).toList();

      // Filter threads based on search query
      return allThreads.where((thread) {
        final query = searchQuery.toLowerCase();

        // Search in user name
        if (thread.userName.toLowerCase().contains(query)) {
          return true;
        }

        // Search in messages
        return thread.messages.any((message) {
          return message.message.toLowerCase().contains(query);
        });
      }).toList();
    });
  }

  // Test function to verify the chat system with new structure
  Future<Map<String, dynamic>> testChatFlow({String? testUserId}) async {
    try {
      final userId = testUserId ?? generateAnonymousUserId();
      final userName = 'Test_User_${DateTime.now().millisecondsSinceEpoch}';

      log('🧪 Starting chat flow test with new structure...');
      log('Test User ID: $userId');
      log('Test User Name: $userName');

      // Step 1: Send a user message
      log('📤 Step 1: Sending user message...');
      final userResult = await sendChatMessage(
        'This is a test message from the Flutter app',
        userId,
        userName,
      );
      log('✅ User message sent: $userResult');

      // Step 2: Send a support response
      log('📤 Step 2: Sending support response...');
      final supportResult = await sendSupportResponse(
        userName,
        'This is a test response from support',
      );
      log('✅ Support response sent: $supportResult');

      return {
        'success': true,
        'testUserId': userId,
        'testUserName': userName,
        'userResult': userResult,
        'supportResult': supportResult,
      };
    } catch (error) {
      log('❌ Chat flow test failed: $error');
      return {'success': false, 'error': error.toString()};
    }
  }
}
