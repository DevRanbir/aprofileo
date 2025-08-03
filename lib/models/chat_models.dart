class ChatMessage {
  final String id;
  final String sender;
  final String message;
  final DateTime timestamp;
  final DateTime expiresAt;
  final String? userId;
  final String? userName;
  final bool edited;
  final DateTime? editedAt;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.message,
    required this.timestamp,
    required this.expiresAt,
    this.userId,
    this.userName,
    this.edited = false,
    this.editedAt,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> data) {
    return ChatMessage(
      id: id,
      sender: data['sender'] ?? '',
      message: data['message'] ?? '',
      timestamp: _parseTimestamp(data['timestamp']),
      expiresAt: _parseTimestamp(data['expiresAt']),
      userId: data['userId'],
      userName: data['userName'],
      edited: data['edited'] ?? false,
      editedAt: data['editedAt'] != null
          ? _parseTimestamp(data['editedAt'])
          : null,
    );
  }

  // Helper method to parse Firestore timestamp or ISO string
  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();

    // Handle Firestore Timestamp
    if (timestamp is Map && timestamp.containsKey('_seconds')) {
      return DateTime.fromMillisecondsSinceEpoch(
        timestamp['_seconds'] * 1000 + (timestamp['_nanoseconds'] ~/ 1000000),
      );
    }

    // Handle Firestore Timestamp object
    try {
      if (timestamp.runtimeType.toString().contains('Timestamp')) {
        return (timestamp as dynamic).toDate();
      }
    } catch (e) {
      // Continue to string parsing
    }

    // Handle ISO string
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return DateTime.now();
      }
    }

    // Handle DateTime object
    if (timestamp is DateTime) {
      return timestamp;
    }

    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      if (userId != null) 'userId': userId,
      if (userName != null) 'userName': userName,
      'edited': edited,
      if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
    };
  }

  bool get isFromUser => sender == 'user';
  bool get isFromSupport => sender == 'support';
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class ChatThread {
  final String id;
  final String userId;
  final String userName;
  final String supportAgentName;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final List<ChatMessage> messages;

  ChatThread({
    required this.id,
    required this.userId,
    required this.userName,
    required this.supportAgentName,
    required this.createdAt,
    required this.lastUpdated,
    required this.messages,
  });

  factory ChatThread.fromMap(String id, Map<String, dynamic> data) {
    List<ChatMessage> messages = [];

    if (data['messages'] != null) {
      final messagesMap = data['messages'] as Map<String, dynamic>;
      messages = messagesMap.entries.map((entry) {
        final messageData = entry.value as Map<String, dynamic>;
        return ChatMessage.fromMap(entry.key, {
          ...messageData,
          'userId': data['userId'],
          'userName': data['userName'],
        });
      }).toList();

      // Filter out expired messages
      final now = DateTime.now();
      messages = messages
          .where((msg) => !msg.isExpired && msg.expiresAt.isAfter(now))
          .toList();

      // Sort messages by timestamp
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    return ChatThread(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous User',
      supportAgentName: data['supportAgentName'] ?? 'Support Team',
      createdAt: ChatMessage._parseTimestamp(data['createdAt']),
      lastUpdated: ChatMessage._parseTimestamp(data['lastUpdated']),
      messages: messages,
    );
  }

  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;
  bool get hasUnreadUserMessages => messages.any(
    (msg) => msg.isFromUser && msg.timestamp.isAfter(lastSupportResponse),
  );

  DateTime get lastSupportResponse {
    final supportMessages = messages.where((msg) => msg.isFromSupport);
    return supportMessages.isNotEmpty
        ? supportMessages.last.timestamp
        : DateTime.fromMillisecondsSinceEpoch(0);
  }

  int get unreadUserMessageCount {
    final lastSupport = lastSupportResponse;
    return messages
        .where((msg) => msg.isFromUser && msg.timestamp.isAfter(lastSupport))
        .length;
  }
}
