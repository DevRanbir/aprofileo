import 'dart:async';
import 'chat_service.dart';
import 'notification_service.dart';
import '../models/chat_models.dart';

class GlobalNotificationManager {
  static GlobalNotificationManager? _instance;
  static GlobalNotificationManager get instance {
    _instance ??= GlobalNotificationManager._internal();
    return _instance!;
  }

  GlobalNotificationManager._internal();

  final ChatService _chatService = ChatService();
  final NotificationService _notificationService = NotificationService();
  final Set<String> _notifiedMessageIds = <String>{};
  StreamSubscription? _messageSubscription;
  bool _isInitialized = false;

  /// Initialize the global notification manager
  /// This should be called once when the app starts
  Future<void> initialize([String? currentUserName]) async {
    if (_isInitialized) return;

    try {
      await _notificationService.initialize();

      // Subscribe to admin notifications topic for background notifications
      await _notificationService.subscribeToTopic('admin_notifications');

      await _preloadExistingMessages(); // Load existing messages first

      // Initialize FCM for the current user if provided
      if (currentUserName != null) {
        await _chatService.initializeFCMForUser(currentUserName);
      }

      _startListeningForMessages();
      _isInitialized = true;
      print('🔔 Global Notification Manager initialized');
      print(
        '🔔 Subscribed to admin_notifications topic for background notifications',
      );
    } catch (e) {
      print('❌ Error initializing Global Notification Manager: $e');
    }
  }

  /// Preload existing messages to avoid notifying about old messages
  Future<void> _preloadExistingMessages() async {
    try {
      // Get current threads once to mark existing messages as seen
      final threads = await _chatService.searchThreads('').first;

      for (final thread in threads) {
        final userMessages = thread.messages
            .where((msg) => msg.isFromUser)
            .toList();

        for (final message in userMessages) {
          final messageKey = '${thread.id}_${message.id}';
          _notifiedMessageIds.add(messageKey);
        }
      }

      print('🔔 Preloaded ${_notifiedMessageIds.length} existing messages');
    } catch (e) {
      print('❌ Error preloading messages: $e');
    }
  }

  /// Start listening for new messages across all threads
  void _startListeningForMessages() {
    _messageSubscription?.cancel(); // Cancel any existing subscription

    _messageSubscription = _chatService
        .searchThreads('')
        .listen(
          (threads) {
            _checkForNewMessages(threads);
          },
          onError: (error) {
            print('Error listening for messages: $error');
          },
        );

    print('🔔 Started listening for new messages globally');
  }

  /// Check for new messages and send notifications
  void _checkForNewMessages(List<ChatThread> threads) {
    for (final thread in threads) {
      // Get the latest user messages from this thread
      final userMessages = thread.messages
          .where((msg) => msg.isFromUser)
          .toList();

      if (userMessages.isNotEmpty) {
        // Sort messages by timestamp to get the actual latest message
        userMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final latestUserMessage = userMessages.last;

        // Create a unique key for this specific message
        final messageKey = '${thread.id}_${latestUserMessage.id}';

        // Only notify if this is truly a new message we haven't seen before
        if (!_notifiedMessageIds.contains(messageKey)) {
          // Check if this message is recent (within last 10 minutes)
          // This prevents notifications for old messages when app starts
          final now = DateTime.now();
          final messageTime = latestUserMessage.timestamp;
          final timeDifference = now.difference(messageTime).inMinutes;

          if (timeDifference <= 10) {
            // Check if this user's chat is currently open in admin screen
            final currentlyOpenChatUserId = _chatService.getCurrentlyOpenChat();
            final isChatCurrentlyOpen =
                currentlyOpenChatUserId == thread.userId;

            if (!isChatCurrentlyOpen) {
              // Add to notified set
              _notifiedMessageIds.add(messageKey);

              // Show notification
              _showNotification(thread, latestUserMessage);
            } else {
              // Mark as seen but don't notify since chat is open
              _notifiedMessageIds.add(messageKey);
              print(
                '🔕 Skipped notification for ${thread.userName} - chat is currently open in admin screen',
              );
            }
          } else {
            // Mark old messages as seen without notifying
            _notifiedMessageIds.add(messageKey);
            print(
              '🔕 Skipped notification for old message from ${thread.userName} (${timeDifference} minutes old)',
            );
          }
        }
      }
    }
  }

  /// Show notification for new message
  Future<void> _showNotification(ChatThread thread, ChatMessage message) async {
    try {
      final title = 'New message from ${thread.userName}';
      final body = message.message.length > 50
          ? '${message.message.substring(0, 50)}...'
          : message.message;

      // Always show local notification for immediate display
      await _notificationService.showNotification(
        title,
        body,
        payload: 'admin_chat_${thread.userId}',
      );

      // Also try to send FCM push notification for background scenarios
      await _sendFCMNotification(thread, message);

      print(
        '🔔 Global notification sent: ${thread.userName} - ${message.message}',
      );
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  /// Send FCM push notification for background scenarios
  Future<void> _sendFCMNotification(
    ChatThread thread,
    ChatMessage message,
  ) async {
    try {
      // Subscribe admin to notifications topic for background notifications
      await _notificationService.subscribeToTopic('admin_notifications');

      // Store notification request in Firestore for background processing
      await _chatService.sendAdminNotificationRequest(
        userName: thread.userName,
        userId: thread.userId,
        messageContent: message.message,
        messageId: message.id,
        threadId: thread.id,
      );

      print('📡 Admin notification request stored for background processing');
    } catch (e) {
      print('❌ Error sending FCM notification: $e');
    }
  }

  /// Stop listening for messages (call when app is disposed)
  void dispose() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    print('🔔 Global Notification Manager disposed');
  }

  /// Clear notification history (useful for testing)
  void clearNotificationHistory() {
    _notifiedMessageIds.clear();
    print('🔔 Notification history cleared');
  }

  /// Get notification service for manual testing
  NotificationService get notificationService => _notificationService;

  /// Check if manager is initialized
  bool get isInitialized => _isInitialized;
}
