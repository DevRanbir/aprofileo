# AProfileo Flutter Chat System

This Flutter application implements a real-time chat system that matches the new Firestore database structure used in your JavaScript implementation. The system supports both user-facing chat and admin management interfaces.

## Database Structure

The app uses the following Firestore structure:

```
chat-messages (Collection)
│
├── safe_username_1 (Document) // Generated from userName using safe ID conversion
│   ├── userName: "Original User Name"
│   ├── userId: "user_1234567890_abcdef123"
│   ├── supportAgentName: "Support Team"
│   ├── createdAt: Timestamp
│   ├── lastUpdated: Timestamp
│   └── messages (Map)
│       ├── msg_1234567890_abc123 (Map)
│       │   ├── sender: "user" | "support"
│       │   ├── message: "message content"
│       │   ├── timestamp: Timestamp
│       │   └── expiresAt: Timestamp (2 hours from creation)
│       └── ...
```

## Features

### User Chat Interface
- **Real-time messaging**: Users can send messages and receive support responses in real-time
- **Message expiration**: Messages automatically expire after 2 hours
- **User identification**: Uses userName as document ID for easy admin management
- **Anonymous user ID generation**: Automatic generation following JavaScript pattern

### Admin Dashboard
- **Real-time thread monitoring**: View all active chat conversations
- **Message management**: Send support responses to users
- **Search functionality**: Search conversations by username or message content
- **Statistics view**: View chat statistics and metrics
- **Cleanup tools**: Remove expired messages and old conversations
- **Test functionality**: Built-in test system to verify chat flow

## Key Components

### Models (`lib/models/chat_models.dart`)
- **ChatMessage**: Represents individual messages with sender, content, timestamps, and expiration
- **ChatThread**: Represents entire conversations with user info and message history

### Services (`lib/services/chat_service.dart`)
- **Chat operations**: Send messages, support responses
- **Real-time subscriptions**: Listen to chat threads and messages
- **Cleanup utilities**: Remove expired messages and conversations
- **Test functions**: Verify system functionality
- **Statistics**: Generate chat metrics

### Screens
- **AdminChatScreen**: Full admin dashboard with thread list and conversation view
- **UserChatScreen**: User-facing chat interface
- **ChatHomePage**: Entry point to choose admin or user interface

### Widgets
- **ChatConversation**: Real-time conversation display and message input
- **ThreadListItem**: Individual thread display in admin list
- **AdminStatsWidget**: Statistics and metrics display

## Message Flow

### User Sends Message
1. User enters message in `UserChatScreen`
2. `ChatService.sendChatMessage()` called with message, userId, and userName
3. Document created/updated in Firestore using safe userName as document ID
4. Message added to `messages` map with generated message ID
5. Real-time listeners update UI immediately

### Support Responds
1. Admin selects conversation in `AdminChatScreen`
2. `ChatService.sendSupportResponse()` called with userName and message
3. Support message added to same document's `messages` map
4. Both user and admin interfaces update in real-time

### Message Expiration
1. All messages have `expiresAt` timestamp (2 hours from creation)
2. Client-side filtering removes expired messages from display
3. Server-side cleanup removes expired messages from database
4. Manual and automatic cleanup available in admin interface

## Firebase Configuration

The app uses the following Firebase services:
- **Firestore**: Real-time database for chat storage
- **Timestamp**: Server-side timestamps for consistency

Required Firestore security rules should allow:
- Users to read/write their own chat documents
- Admins to read/write all chat documents
- Cleanup of expired documents

## Usage

### Running the App
1. Ensure Firebase is configured with your project
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to start the application

### Admin Features
- Access admin dashboard from home screen
- View all active conversations in left panel
- Click conversation to view/respond to messages
- Use test button to create sample conversations
- Use cleanup button to remove expired messages
- Toggle statistics view for system metrics

### User Features
- Enter name to start chat from home screen
- Send messages to support team
- View conversation history
- Messages expire automatically after 2 hours

## Technical Notes

### Document ID Generation
Username is converted to safe document ID using the pattern:
```dart
String _createSafeDocId(String userName) {
  return userName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '_')
      .replaceAll(RegExp(r'_{2,}'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}
```

### Message ID Generation
Messages use timestamp-based IDs:
```dart
String generateMessageId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = (timestamp % 1000000).toString().substring(0, 6);
  return 'msg_${timestamp}_$random';
}
```

### Real-time Updates
All chat interfaces use Firestore streams for real-time updates:
- User chat subscribes to their specific document
- Admin dashboard subscribes to all documents
- Automatic UI updates when messages are added/removed

## Testing

The system includes built-in testing functionality:
1. Click the test button in admin dashboard
2. System creates a test user and conversation
3. Sends both user message and support response
4. Verifies real-time functionality works correctly

This matches the JavaScript `testChatFlow()` function behavior.

## Dependencies

- `firebase_core`: Firebase initialization
- `cloud_firestore`: Firestore database
- `intl`: Date/time formatting
- `flutter/material`: UI components

## Matching JavaScript Implementation

This Flutter implementation closely matches the JavaScript chat functions:
- Same document structure using userName as document ID
- Same message expiration logic (2 hours)
- Same message ID generation pattern
- Same cleanup and testing functionality
- Compatible with existing web-based chat system
